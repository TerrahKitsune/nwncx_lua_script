using System.Diagnostics;
using System.IO.MemoryMappedFiles;
using System.Text;
using System.Text.RegularExpressions;

namespace SharedQueue
{
    public class SharedQueue : IDisposable
    {
        public record QueueData(Guid Id, long Commit, long Timestamp, string Data);

        private static readonly int RetentionTime = 5;
        private static readonly int MaxSize = 1048576;
        private readonly Stopwatch _rebalanceTime = new Stopwatch();
        private readonly MemoryMappedFile _mappedFile;
        private readonly MemoryMappedViewAccessor _viewAccessor;
        private bool disposedValue;
        private long _currentCommit;

        public SharedQueue(string name)
        {
            _rebalanceTime.Start();
            _currentCommit = 0;
            _mappedFile = MemoryMappedFile.CreateOrOpen(name, MaxSize);
            _viewAccessor = _mappedFile.CreateViewAccessor(0, MaxSize, MemoryMappedFileAccess.ReadWrite);

            byte[] header = new byte[37];
            _viewAccessor.ReadArray(0, header, 0, header.Length);
            string headerString = Encoding.UTF8.GetString(header);

            Regex regex = new Regex(@"^.{8}\-.{4}\-.{4}\-.{4}\-.{12}\|$");

            if (regex.IsMatch(headerString))
            {
                QueueId = Guid.Parse(headerString.Substring(0, headerString.Length - 1));
            }
            else
            {
                QueueId = Guid.NewGuid();
                headerString = QueueId.ToString() + "|";
                header = Encoding.ASCII.GetBytes(headerString);
                _viewAccessor.WriteArray(0, header, 0, header.Length);
            }

            Id = Guid.NewGuid();

            _viewAccessor.Write(37, (byte)0);
        }

        ~SharedQueue()
        {
            Dispose(disposing: false);
        }

        public Guid QueueId { get; init; }

        public Guid Id { get; init; }

        public bool IsLocked => _viewAccessor.ReadByte(37) != 0;

        public short GetCount()
        {
            return _viewAccessor.ReadInt16(38);
        }

        public long GetCommit()
        {
            return _viewAccessor.ReadInt64(40);
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }

        public async Task<bool> PostMessage(string message, CancellationToken cancellationToken)
        {
            int currentOffset = 48;
            await SetLocked(true, cancellationToken);

            try
            {
                bool hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
                short msgLen;
                long msgCommit;
                long msgTime;
                bool hasOld = false;
                long timestamp = DateTimeOffset.Now.ToUnixTimeSeconds();

                while (hasMessage)
                {
                    msgLen = _viewAccessor.ReadInt16(currentOffset + 1);
                    msgCommit = _viewAccessor.ReadInt64(currentOffset + 3);
                    msgTime = _viewAccessor.ReadInt64(currentOffset + 11);

                    if (timestamp - msgTime > RetentionTime)
                    {
                        hasOld = true;
                    }

                    currentOffset += msgLen + 3;
                    hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
                }

                byte[] encoded = Encoding.Latin1.GetBytes(Id.ToString() + "|" + message);
                msgLen = Convert.ToInt16(encoded.Length + 16);

                if (msgLen + currentOffset >= MaxSize)
                {
                    if (hasOld)
                    {
                        Rebalance();
                        await SetLocked(false, cancellationToken);
                        return await PostMessage(message, cancellationToken);
                    }

                    return false;
                }

                _viewAccessor.Write(currentOffset, (byte)1);
                currentOffset++;
                _viewAccessor.Write(currentOffset, msgLen);
                currentOffset += sizeof(short);
                _viewAccessor.Write(currentOffset, IncrementCommit());
                currentOffset += sizeof(long);
                _viewAccessor.Write(currentOffset, DateTimeOffset.Now.ToUnixTimeSeconds());
                currentOffset += sizeof(long);
                _viewAccessor.WriteArray(currentOffset, encoded, 0, encoded.Length);
                SetCount(Convert.ToInt16(GetCount() + 1));

                return true;
            }
            catch
            {
                throw;
            }
            finally
            {
                await SetLocked(false, cancellationToken);
            }
        }

        public async Task<IReadOnlyCollection<QueueData>> GetMessages(CancellationToken cancellationToken)
        {
            List<QueueData> result = null;
            int currentOffset = 48;
            await SetLocked(true, cancellationToken);

            try
            {
                bool hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
                short msgLen;
                long msgCommit;
                long msgTime;
                bool hasOld = false;
                long timestamp = DateTimeOffset.Now.ToUnixTimeSeconds();

                while (hasMessage)
                {
                    msgLen = _viewAccessor.ReadInt16(currentOffset + 1);
                    msgCommit = _viewAccessor.ReadInt64(currentOffset + 3);
                    msgTime = _viewAccessor.ReadInt64(currentOffset + 11);

                    if (msgCommit > _currentCommit)
                    {
                        result ??= new List<QueueData>();
                        byte[] msg = new byte[msgLen - 16];
                        _viewAccessor.ReadArray(currentOffset + 19, msg, 0, msg.Length);
                        string raw = Encoding.Latin1.GetString(msg);
                        int split = raw.IndexOf('|');

                        QueueData queueData = new QueueData(
                            Guid.Parse(raw.Substring(0, split)),
                            msgCommit,
                            msgTime,
                            raw.Substring(split + 1));

                        result.Add(queueData);
                    }
                    else if (timestamp - msgTime > RetentionTime)
                    {
                        hasOld = true;
                    }

                    currentOffset += msgLen + 3;
                    hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
                }

                if (hasOld && _rebalanceTime.ElapsedMilliseconds > RetentionTime * 1000)
                {
                    Rebalance();
                    _rebalanceTime.Restart();
                }

                _currentCommit = GetCommit();

                return result;
            }
            catch
            {
                throw;
            }
            finally
            {
                await SetLocked(false, cancellationToken);
            }
        }

        protected void Rebalance()
        {
            int currentOffset = 48;
            bool hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
            if (!hasMessage)
            {
                return;
            }
            short msgLen;
            long msgCommit;
            long msgTime;
            long timestamp = DateTimeOffset.Now.ToUnixTimeSeconds();
            List<QueueData> result = new List<QueueData>();

            while (hasMessage)
            {
                _viewAccessor.Write(currentOffset, (byte)0);
                msgLen = _viewAccessor.ReadInt16(currentOffset + 1);
                msgCommit = _viewAccessor.ReadInt64(currentOffset + 3);
                msgTime = _viewAccessor.ReadInt64(currentOffset + 11);

                if (timestamp - msgTime <= RetentionTime)
                {
                    byte[] msg = new byte[msgLen - 16];
                    _viewAccessor.ReadArray(currentOffset + 19, msg, 0, msg.Length);
                    string raw = Encoding.Latin1.GetString(msg);
                    int split = raw.IndexOf('|');

                    QueueData queueData = new QueueData(
                        Guid.Parse(raw.Substring(0, split)),
                        msgCommit,
                        msgTime,
                        raw.Substring(split + 1));

                    result.Add(queueData);
                }

                currentOffset += msgLen + 3;
                hasMessage = _viewAccessor.ReadByte(currentOffset) == 1;
            }

            for (int i = 48; i < currentOffset; i++)
            {
                _viewAccessor.Write(i, (byte)0);
            }

            currentOffset = 48;

            foreach (QueueData item in result)
            {
                byte[] encoded = Encoding.Latin1.GetBytes(item.Id.ToString() + "|" + item.Data);
                msgLen = Convert.ToInt16(encoded.Length + 16);

                _viewAccessor.Write(currentOffset, (byte)1);
                currentOffset++;
                _viewAccessor.Write(currentOffset, msgLen);
                currentOffset += sizeof(short);
                _viewAccessor.Write(currentOffset, item.Commit);
                currentOffset += sizeof(long);
                _viewAccessor.Write(currentOffset, item.Timestamp);
                currentOffset += sizeof(long);
                _viewAccessor.WriteArray(currentOffset, encoded, 0, encoded.Length);
                currentOffset += encoded.Length;
            }

            SetCount(Convert.ToInt16(result.Count));
        }

        protected long IncrementCommit()
        {
            long current = GetCommit() + 1;
            _viewAccessor.Write(40, current);

            return current;
        }

        protected void SetCount(short cnt)
        {
            _viewAccessor.Write(38, cnt);
        }

        protected async Task SetLocked(bool isReading, CancellationToken cancellationToken)
        {
            if (isReading)
            {
                int tries = 0;

                while (IsLocked)
                {
                    if (++tries > 100)
                    {
                        await Task.Delay(1, cancellationToken);

                        if (tries > 2000)
                        {
                            break;
                        }
                    }
                }

                _viewAccessor.Write(37, (byte)1);
            }
            else
            {
                _viewAccessor.Write(37, (byte)0);
            }
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!disposedValue)
            {
                _viewAccessor?.Dispose();
                _mappedFile?.Dispose();
                disposedValue = true;
            }
        }
    }
}
