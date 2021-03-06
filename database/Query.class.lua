--[[
                                       _ 
                                      | |
  _ __   _____      _____ _ __ ___  __| |
 | '_ \ / _ \ \ /\ / / _ \ '__/ _ \/ _` |
 | |_) | (_) \ V  V /  __/ | |  __/ (_| |
 | .__/ \___/ \_/\_/ \___|_|  \___|\__,_|
 | |                                                                              
 | |__  _   _   
 | '_ \| | | |  https://github.com/sanyisasha
 | |_) | |_| |  @Author SaSha <Molnár Sándor>
 |_.__/ \__, |
     _____/  /   _____  _           
    / ______/   / _____| |          
   | (___   __ _| (___ | |__   __ _ 
    \___ \ / _` |\___ \| '_ \ / _` |
    ____) | (_| |____) | | | | (_| |
   |_____/ \__,_|_____/|_| |_|\__,_|
]]


class "Query" ("Object") {
	SORT_DESC = 1,
	SORT_ASC = 2,

	schemaCache = {},
	
	handler = function(self)
		return exports['mta-mysql']
	end,

	select = function(self, selects)
		return SelectQuery(selects)
	end,

	insert = function(self, _table, values)
		assert(values, '[Query] values can\'t be blank.')

		local sql = 'INSERT INTO `'.._table..'` '

		local _args = '('
		local _values = '('

		for i,v in pairs(values) do
			_args = _args..'`'..i..'`, '
			_values = _values..'"'..self:handler():DBEscape(v)..'", '
		end
		
		_values = string.sub(_values, 0, -3)
		_args = string.sub(_args, 0, -3)

		_args = _args..') VALUES '
		_values = _values..')'

		sql = sql.._args.._values

		return self:handler():DBPollQuery(sql)
	end,

	update = function(self, _table, values, condition)
		assert(values, '[Query] values can\'t be blank.')
		assert(condition, '[Query] condition can\'t be blank.')

		local sql = 'UPDATE `'.._table..'` SET '

		local _values = ''
		local _where = ' WHERE '

		local _condition = {}

		for key, value in pairs(condition) do
			if tonumber(key) then
				-- {'NOT IN', 'id', {3,4,5}} => `id` NOT IN (...)
				local _value = value[3]
				if type(value[3]) == 'table' then
					_value = '("'..table.concat(value[3], '","')..'")'
				end
				table.insert(_condition, {_value, 'AND_'..value[1], value[2]})
			else
				if type(value) ~= 'table' then
					table.insert(_condition, {value, 'AND', key})
				else
					table.insert(_condition, {'("'..table.concat(value, '","')..'")', 'AND_IN', key})
				end
			end
		end

		-- TODO: implement orWhere
		
		for key, value in pairs(_condition) do
			if value[2] == 'AND' or value[2] == 'OR' then
				if _where ~= ' WHERE ' then _where = _where..' '..value[2] end
				_where = _where..' `'..value[3]..'` = "'..self:handler():DBEscape(value[1])..'"'
			else
				local _types = explode('_', value[2])
				if _where ~= ' WHERE ' then _where = _where..' '.._types[1] end
				_where = _where..' `'..value[3]..'` '.._types[2]..' '..value[1]
			end
		end

		if _where == ' WHERE ' then _where = ' WHERE 1=1 ' end

		for key, value in pairs(values) do
			_values = _values..'`'..key..'` = "'..self:handler():DBEscape(value)..'", '
		end

		_values = string.sub(_values, 0, -3)

		sql = sql.._values.._where

		return self:handler():DBExec(sql)
	end,

	delete = function(self, _table, condition)
		assert(condition, '[Query] condition can\'t be blank.')

		local sql = 'DELETE FROM `'.._table..'`'

		local _where = ' WHERE '

		local _condition = {}
		for key, value in pairs(condition) do
			if tonumber(key) then
				-- {'NOT IN', 'id', {3,4,5}} => `id` NOT IN (...)
				local _value = value[3]
				if type(value[3]) == 'table' then
					_value = '("'..table.concat(value[3], '","')..'")'
				end
				table.insert(_condition, {_value, 'AND_'..value[1], value[2]})
			else
				if type(value) ~= 'table' then
					table.insert(_condition, {value, 'AND', key})
				else
					table.insert(_condition, {'("'..table.concat(value, '","')..'")', 'AND_IN', key})
				end
			end
		end

		-- TODO: implement orWhere
		for key, value in pairs(_condition) do
			if value[2] == 'AND' or value[2] == 'OR' then
				if _where ~= ' WHERE ' then _where = _where..' '..value[2] end
				_where = _where..' `'..value[3]..'` = "'..self:handler():DBEscape(value[1])..'"'
			else
				local _types = explode('_', value[2])
				if _where ~= ' WHERE ' then _where = _where..' '.._types[1] end
				_where = _where..' `'..value[3]..'` '.._types[2]..' '..value[1]
			end
		end

		sql = sql.._where

		return self:handler():DBExec(sql)

	end,

	getSchema = function(self, _table)
		if self.schemaCache[_table] then return self.schemaCache[_table] end
		local database = self:handler():DBGetDatabase()
		local data = self:handler():DBPollQuery("SELECT COLUMN_NAME as value FROM `INFORMATION_SCHEMA`.`COLUMNS` WHERE `TABLE_SCHEMA`='"..database.."' AND `TABLE_NAME`='".._table.."'")
		self.schemaCache[_table] = data
		return data
	end,
}
