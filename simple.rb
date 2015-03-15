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

	def reduce
		if left.reducible?
			Add.new(left.reduce, right)
		elsif right.reducible?
			Add.new(left, right.reduce)
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

	def reduce
		if left.reducible?
			Multiply.new(left.reduce, right)
		elsif right.reducible?
			Multiply.new(left, right.reduce)
		else
			Number.new(left.value * right.value)
		end
	end
end

expression = Add.new(
		Multiply.new(Number.new(1), Number.new(2)),
		Multiply.new(Number.new(3), Number.new(4))
	)
