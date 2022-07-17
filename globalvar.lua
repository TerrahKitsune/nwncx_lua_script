local vars = {Cache={}};

function vars:Start(db)

	self.DB = db;

	db:Query([[CREATE TABLE "vars" (
	"Name"	TEXT NOT NULL,
	"Type"	INTEGER NOT NULL,
	"Value"	TEXT NOT NULL,
	PRIMARY KEY("Name"));]]);
end

function vars:Get(name, default)

	local value = self.Cache[name];

	if type(value) ~= "nil" then
		return value;
	end
	
	assert(self.DB:Query("SELECT * FROM vars WHERE Name LIKE @id;", {id=name}));
	
	if self.DB:Fetch() then 
	
		local row = self.DB:GetRow();
		
		if row.Type == 1 then
			value = (tonumber(row.Value) == 1);
		elseif row.Type == 2 then 
			value = tonumber(row.Value);
		elseif row.Type == 3 then 
			value = tostring(row.Value);
		elseif row == 4 then
			value = Json.Create():Decode(row.Value);
		else
			error("Invalid type "..tostring(row));
		end
	
		self.Cache[name] = value;
		return value;
	else 
		self:Set(name, default);
		self.Cache[name] = default;
		return default;
	end	
end

function vars:Set(name, value)

	local Type = type(value);
	local setvalue;
	
	if Type == "boolean" then
		if value then 
			setvalue = "1";
		else 
			setvalue = "0";
		end
		Type = 1;
	elseif Type == "number" then 
		setvalue = tostring(value);
		Type = 2;
	elseif Type == "string" then 
		setvalue = value;
		Type = 3;
	elseif Type == "table" then 
		setvalue = Json.Create():Encode(value);
		Type = 4;
	else 
		error("Invalid type "..tostring(Type));
	end

	assert(self.DB:Query([[replace into vars (Name, Type, Value)values(@id,@t, @v);]], {id=name, t=Type, v=setvalue}));
end

local linkedListMeta ={
	__metatable="LinkedList", 
	__index=function(tbl, idx) 
	
		idx = tonumber(idx);
		if idx == nil or idx <= 0 then 
			return nil;
		end

		local c = tbl.First;
		local nth = 1;
		
		while c do 
		
			if nth == idx then 
				return c.Value;
			else 
				nth = nth + 1;
			end
		
			c = c.Next;
		end
	
		return nil;
	end,
	__len=function(tbl)
		return tbl:Len();
	end};

function vars:CreateLinkedList()

	local linkedList = {Count=0};

	function linkedList:Len()
		return self.Count;
	end

	function linkedList:AddFirst(value)
	
		local node = {
			Value=value,
			Next = self.First,
			Id = nil
		};
		
		node.Id = tonumber(tostring(node):sub(8), 16);
		
		self.Count = self.Count + 1;
		self.First = node;	
		
		return node.Id;
	end

	function linkedList:AddLast(value)
	
		local node = {
			Value=value,
			Next = nil,
			Id = nil
		};
		
		node.Id = tonumber(tostring(node):sub(8), 16);
		
		self.Count = self.Count + 1;
		
		if not self.First then
			self.First = node;
			return node.Id;
		end 
		
		local c = self.First;
		
		while c do 
	
			if not c.Next then 
				break;
			end
			
			c = c.Next;
		end	

		c.Next = node;
		return node.Id;
	end

	function linkedList:Remove(id)
	
		if self.First and self.First.Id == id then 
			self.First = self.First.Next;
			self.Count = self.Count - 1;
			return true;
		end 
	
		local c = self.First;
		local prev;
		while c do 
	
			if c.Id == id then 
			
				prev.Next = c.Next;
				self.Count = self.Count - 1;
				return true;
			end
			
			prev = c;
			c = c.Next;
		end	 
		
		return false;
	end

	function linkedList:RemoveFirst()
	
		if not self.First then 
			return false;
		end 
	
		self.Count = self.Count - 1;
		self.First = self.First.Next;

		return true;
	end
	
	function linkedList:RemoveLast()
	
		if not self.First then 
			return false;
		end 
	
		local c = self.First;
		local prev; 
		
		while c do
		
			if not c.Next then 
			
				if prev then	
					prev.Next = nil;
				else 
					self.First = nil;
				end
				
				break;
			end 
		
			prev = c;
			c = c.Next; 
		end 
		
		self.Count = self.Count - 1;
		return true;
	end
	
	function linkedList:All()
	
		local current = self.First;
		
		return function()
			local c = current;
			if c then 
				current = current.Next;
				return c.Id, c.Value;
			end		
		end
	end

	function linkedList:Set(id, value)
	
		local c = self.First;
		while c do
		
			if c.Id == id then 
	
				c.Value = value;
				return true;
			end 
			
			c = c.Next;
		end
		
		return false;
	end
	
	function linkedList:LastToFirst()
	
		if not self.First then 
			return false;
		end 
	
		local c = self.First;
		local prev; 
		
		while c do
		
			if not c.Next then 
			
				if prev then	
					prev.Next = nil;
				else 
					self.First = nil;
				end
				
				break;
			end 
		
			prev = c;
			c = c.Next; 
		end
		
		c.Next = self.First;
		self.First = c;
	end

	setmetatable(linkedList, linkedListMeta);

	return linkedList;
end 


return vars;