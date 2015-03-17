class Number < Struct.new(:value)
	def to_s
		value.to_s
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		return false
	end
end

class Boolean < Struct.new(:value)
	def to_s
		value.to_s
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		return false
	end
end

class And < Struct.new(:left, :right)
	def to_s
		"#{left} & #{right}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		return true
	end

	def reduce(environment)
		if left.reducible?
			And.new(left.reduce(environment), right)
		elsif right.reducible?
			And.new(left, right.reduce(environment))
		else
			if left.value and right.value 
				Boolean.new(true)
			else
				Boolean.new(false)
			end
		end
	end
end

class Add < Struct.new(:left, :right)
	def to_s
		"#{left} + #{right}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		return true
	end

	def reduce(environment)
		if left.reducible?
			Add.new(left.reduce(environment), right)
		elsif right.reducible?
			Add.new(left, right.reduce(environment))
		else
			Number.new(left.value + right.value)
		end
	end
end

class Multiply < Struct.new(:left, :right)
	def to_s
		"#{left} * #{right}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		return true
	end

	def reduce(environment)
		if left.reducible?
			Multiply.new(left.reduce(environment), right)
		elsif right.reducible?
			Multiply.new(left, right.reduce(environment))
		else
			Number.new(left.value * right.value)
		end
	end
end


class LessThan < Struct.new(:left, :right)
	def to_s
		"#{left} < #{right}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		if left.reducible?
			LessThan.new(left.reduce(environment), right)
		elsif right.reducible?
			LessThan.new(left, right.reduce(environment))
		else
			Boolean.new(left.value < right.value)
		end
	end
end

class Equal < Struct.new(:left, :right)
	def to_s
		"#{left} == #{right}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		if left.reducible?
			Equal.new(left.reduce(environment), right)
		elsif right.reducible?
			Equal.new(left, right.reduce(environment))
		elsif left.value == right.value
			Boolean.new(true)
		else
			Boolean.new(false)
		end
	end
end

class Variable < Struct.new(:name)
	def to_s
		name.to_s
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		environment[name]
	end
end

class DoNothing
	def to_s
		"do-nothing"
	end

	def inspect
		"<<#{self}>>"
	end

	def ==(other_statement)
		other_statement.instance_of?(DoNothing)
	end

	def reducible?
		false
	end
end

class Assign < Struct.new(:name, :expression)
	def to_s
		"#{name} = #{expression}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		if expression.reducible?
			[Assign.new(name, expression.reduce(environment)), environment]
		else
			[DoNothing.new, environment.merge({name => expression})]
		end
	end
end

class If < Struct.new(:expression, :statement1, :statement2) 
	def to_s
		"if (#{expression}) { #{statement1} } else { #{statement2} }"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		if expression.reducible?
			[If.new(expression.reduce(environment), statement1, statement2), environment]
		elsif expression.value == true
			[statement1, environment]
#			statement1.reduce(environment)
		else
			[statement2, environment]
#			statement2.reduce(environment)
		end
	end
end

class Sequence < Struct.new(:first, :second)
	def to_s
		"#{first}; #{second}"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		case first
		when DoNothing.new
			[second, environment]
		else 
			reduced_first, reduced_environment = first.reduce(environment)
			[Sequence.new(reduced_first, second), reduced_environment]
		end
	end
end

class While < Struct.new(:condition, :statement)
	def to_s
		"while (#{condition}) { #{statement} }"
	end

	def inspect
		"<<#{self}>>"
	end

	def reducible?
		true
	end

	def reduce(environment)
		[If.new(condition, Sequence.new(statement, self), DoNothing.new), environment]
	end
end

class Machine < Struct.new(:statement, :environment)
	def step
		self.statement, self.environment = statement.reduce(environment)
	end

	def run
		while statement.reducible?
			puts "#{statement}, #{environment}"
			step
		end
		puts "#{statement}, #{environment}"
	end
end

expression = Add.new(
		Multiply.new(Number.new(1), Number.new(2)),
		Multiply.new(Number.new(3), Number.new(4))
	)

# If
#Machine.new(
#	If.new(LessThan.new(Variable.new(:x), Variable.new(:z)),
#		   Assign.new(:y, Number.new(1)),
#		   Assign.new(:y, Number.new(2))),
#	{x: Number.new(4), z: Number.new(3)}
#).run

# While
Machine.new(
	While.new(
		LessThan.new(
			Variable.new(:x), 
			Number.new(3)
		),
		Sequence.new(
			Assign.new(
				:y, 
				Add.new(
					Variable.new(:y), 
					Number.new(1)
				)
			),
			Assign.new(
				:x, 
				Add.new(Variable.new(:x), Number.new(1))
			)
		)
	),
	{x: Number.new(0), y: Number.new(3)}
).run

class Number
	def evaluate(environment)
		self
	end
end

class Boolean
	def evaluate(environment)
		self
	end
end

class Variable
	def evaluate(environment)
		environment[name]
	end
end

class Add
	def evaluate(environment)
		Number.new(left.evaluate(environment).value + right.evaluate(environment).value)
	end
end

class Multiply
	def evaluate(environment)
		Number.new(left.evaluate(environment).value * right.evaluate(environment).value)
	end
end

class LessThan
	def evaluate(environment)
		Boolean.new(left.evaluate(environment).value < right.evaluate(environment).value)
	end
end

class Assign
	def evaluate(environment)
		environment.merge({ name => expression.evaluate(environment) })
	end
end

class DoNothing
	def evaluate(environment)
		environment
	end
end

class If
	def evaluate(environment)
		case condition.evaluate(environment)
		when Boolean.new(true)
			statement1.evaluate(environment)
		when Boolean.new(false)
			statement2.evaluate(environment)
		end
	end
end

class While 
	def evaluate(environment)
		case condition.evaluate(environment)
		when Boolean.new(true)
			evaluate(statement.evaluate(environment))
		when Boolean.new(false)
			environment
		end
	end
end

class Sequence
	def evaluate(environment)
		second.evaluate(first.evaluate(environment))
	end
end

statement = Sequence.new(
				Assign.new(:x, Add.new(Number.new(1), Number.new(1))),
				Assign.new(:y, Add.new(Variable.new(:x), Number.new(3)))
			)

statement.evaluate({})

statement2 = While.new(
				LessThan.new(Variable.new(:x), Number.new(5)),
				Assign.new(:x, Multiply.new(Variable.new(:x), Number.new(3)))
			 )
statement2.evaluate({x: Number.new(1)})
