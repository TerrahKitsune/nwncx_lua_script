using System.Diagnostics;

namespace SharedQueue
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            using (CancellationTokenSource source = new CancellationTokenSource())
            using (SharedQueue sharedQueue = new SharedQueue("Local\\NWN"))
            {
                CancellationToken cancellationToken = source.Token;

                while (!cancellationToken.IsCancellationRequested)
                {
                    IReadOnlyCollection<SharedQueue.QueueData> data = await sharedQueue.GetMessages(cancellationToken);

                    if (data != null)
                    {
                        foreach (var item in data)
                        {
                            Console.WriteLine("{0} {1}: {2}", item.Commit, item.Id, item.Data);
                        }
                    }
                    else
                    {
                        Console.Title = string.Format("Cnt: {0} Lock: {1}", sharedQueue.GetCount(), sharedQueue.IsLocked);
                        await Task.Delay(1000, cancellationToken);
                    }
                }
            }
        }
    }
}
