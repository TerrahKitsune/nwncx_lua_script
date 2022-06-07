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

return vars;