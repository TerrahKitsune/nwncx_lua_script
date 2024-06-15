local SharedQueue = {QIdOffset = 0, QCountOffset=38, QLockOffset=37, QCommitOffset=40, QFirstMsgOffset=48, MaxSize = 1048576, RetentionTime = 5};

SharedQueue.Q = Stream.CreateSharedMemoryStream("Global\\NWN", SharedQueue.MaxSize) or Stream.CreateSharedMemoryStream("NWN", SharedQueue.MaxSize);
SharedQueue.QId = SharedQueue.Q:Read(37);
SharedQueue.QId = SharedQueue.QId:match("(........%-....%-....%-....%-............)|");
SharedQueue.Id = UUID();

if SharedQueue.QId then
	print("Existing: "..SharedQueue.QId);
else 
	SharedQueue.QId = UUID();
	print("New: "..SharedQueue.QId);
	SharedQueue.Q:Seek();
	SharedQueue.Q:Write(SharedQueue.QId.."|");
	SharedQueue.Q:WriteByte(0);
	SharedQueue.Q:WriteShort(0);
	SharedQueue.Q:WriteLong(0);
end

function SharedQueue:GetCount()
	self.Q:Seek(self.QCountOffset);
	return self.Q:ReadShort();
end

function SharedQueue:SetCount(cnt)
	self.Q:Seek(self.QCountOffset);
	self.Q:WriteShort(cnt);
end

function SharedQueue:SetLocked(isReading, isWrite)

	self.Q:Seek(self.QLockOffset);

	if isReading then
	
		local tries = 0;
	
		while self.Q:PeekByte() ~= 0 do
			
			tries = tries + 1;
			if isWrite then
			
				Sleep();			
				if tries > 5000 then
					break;
				end
			else				
				if tries > 10000 then
					Sleep();
				elseif tries > 15000 then
					break;
				end			
			end
		end
	
		SharedQueue.Q:WriteByte(1);
	else
		SharedQueue.Q:WriteByte(0);
	end
end

function SharedQueue:IsLocked()
	self.Q:Seek(self.QLockOffset);
	return self.Q:PeekByte() ~= 0;
end

function SharedQueue:IncrementCommit()
	
	local pos = self.Q:pos();
	local commit = self:GetCommit();	
	commit = commit + 1;
	self.Q:Seek(self.QCommitOffset);
	self.Q:WriteLong(commit);
	self.Q:Seek(pos);
	
	return commit;
end

function SharedQueue:GetCommit()
	self.Q:Seek(self.QCommitOffset);
	return self.Q:ReadLong();
end

SharedQueue.Commit = 0;

function SharedQueue:PostMessage(msg)

	self:SetLocked(true, true);
	local currentOffset = self.QFirstMsgOffset;
	self.Q:Seek(currentOffset);
	local hasMsg = self.Q:ReadByte() == 1;
	local len, commit, msgTime;
	local currentTime = os.time();
	local hasOldMessages = false;

	while hasMsg do
		len = self.Q:ReadShort();
		commit = self.Q:ReadLong();
		msgTime = self.Q:ReadLong();
		
		if currentTime - msgTime <= self.RetentionTime then
			hasOldMessages = true;
		end
		
		currentOffset = currentOffset + len + 3;
		self.Q:Seek(currentOffset);
		hasMsg = self.Q:ReadByte() == 1;
	end

	len = 37 + 16 + msg:len();
	
	if len + currentOffset >= self.MaxSize then
		self:SetLocked(false);
		
		if hasOldMessages then
			self:Rebalance();
			return self:PostMessage(msg);
		end
		
		return false;
	end 
	
	self.Q:Seek(currentOffset);
	self.Q:WriteByte(1);
	self.Q:WriteShort(len);
	self.Q:WriteLong(self:IncrementCommit());
	self.Q:WriteLong(os.time());
	self.Q:Write(SharedQueue.Id.."|"..msg);
	self:SetCount(self:GetCount()+1);
	self:SetLocked(false);
	
	return true;
end

function SharedQueue:Rebalance()

	local copy = Stream.Create(self.MaxSize);
	copy:SetLength(self.MaxSize);
	self:SetLocked(true, true);
	
	self.Q:Seek(0);
	copy:Write(self.Q:Read(self.QFirstMsgOffset));
	local cnt = 0;
	self.Q:Seek(self.QFirstMsgOffset);
	local hasMsg = self.Q:ReadByte() == 1;
	local currentTime = os.time();
	
	while hasMsg do
		local len = self.Q:ReadShort();
		commit = self.Q:ReadLong();
		msgTime = self.Q:ReadLong();
		
		if currentTime - msgTime <= self.RetentionTime then
			copy:WriteByte(1);
			copy:WriteShort(len);
			copy:WriteLong(commit);
			copy:WriteLong(msgTime);
			copy:Write(self.Q:Read(len - 16));
			cnt = cnt + 1;
		end
		
		hasMsg = self.Q:ReadByte() == 1;
	end
	
	copy:Seek();
	self.Q:Seek()
	self.Q:Write(copy:Read());
	self:SetCount(cnt);
	self:SetLocked(false);
end

function SharedQueue:GetMessages()

	self:SetLocked(true, false);
	local currentOffset = self.QFirstMsgOffset;
	self.Q:Seek(currentOffset);
	local hasMsg = self.Q:ReadByte() == 1;
	local len = 0;
	local commit;
	local msgTime;
	local currentTime = os.time();
	local hasOldMessages = false;
	local result = {};
	
	while hasMsg do
		
		local len = self.Q:ReadShort();
		currentOffset = currentOffset + len + 3;
		commit = self.Q:ReadLong();
		msgTime = self.Q:ReadLong();

		if commit > self.Commit then
			
			local msg = {};
			msg.Commit = commit;
			msg.Time = msgTime;
			msg.Text = self.Q:Read(len - 16);
			self.Commit = msg.Commit;
			self:SetLocked(false);
			
			msg.Id, msg.Text = msg.Text:match("(.-)|(.+)");
			
			table.insert(result, msg);
			
		elseif not hasOldMessages and currentTime - msgTime > self.RetentionTime then
			hasOldMessages = true;
		end
		
		self.Q:Seek(currentOffset);
		hasMsg = self.Q:ReadByte() == 1;	
	end
	
	self:SetLocked(false);
	
	if hasOldMessages then
		self:Rebalance();
	end
	
	return result;
end

SharedQueue:PostMessage("Test 1");
SharedQueue:PostMessage("Test 2");
SharedQueue:PostMessage("Test 3");
SharedQueue:PostMessage("Test 4");
SharedQueue:PostMessage("Test 5");

while false do
	print(SharedQueue:PostMessage(UUID()));
end

local function Dump(str)
	
	for i = 1, #str do
		local char = string.sub(str, i, i)
		io.write(char)
	end
	print("");
end

SharedQueue.Q:Seek();
--Dump(SharedQueue.Q:Read(1000));
local msgs;

while true do 
	Sleep(1000); 
	print(SharedQueue:GetCount(), SharedQueue:IsLocked(), SharedQueue:GetCommit());
	msgs = SharedQueue:GetMessages();
	while #msgs > 0 do
		for _, msg in ipairs(msgs) do
			print(SharedQueue:GetCount(), msg.Time, msg.Commit, msg.Id, msg.Text);
		end
		msgs = SharedQueue:GetMessages();
	end
end

return SharedQueue;