class Stack < Struct.new(:contents)
	def push(character)
		Stack.new([character] + contents)
	end

	def pop()
		Stack.new(contents.drop(1))
	end
	
	def top
		contents.first
	end

	def inspect
		"#<Stack (#{top})#{contents.drop(1).join}>"
	end
end

stack = Stack.new(['a', 'b', 'c', 'd', 'e'])
stack.top
stack.pop.pop.top
stack.push('x')

class PDAConfiguration < Struct.new(:state, :stack)
	STUCK_STATE = Object.new

	def stuck
		PDAConfiguration.new(STUCK_STATE, stack)
	end

	def stuck?
		state == STUCK_STATE
	end

	def inspect
		"#<PDAConfiguration #{state}/#{stack.inspect}>"
	end
end

class PDARule < Struct.new(:state, :character, :next_state, :pop_character, :push_characters)
	def applies_to?(configuration, character)
		self.state == configuration.state &&
			self.pop_character == configuration.stack.top &&
			self.character == character
	end

	def follow(configuration)
		PDAConfiguration.new(next_state, next_stack(configuration))
	end
	
	def next_stack(configuration)
		popped_stack = configuration.stack.pop

		push_characters.reverse.
			inject(popped_stack) { |stack, character| stack.push(character) }
	end

	def inspect
		"#<PDARule #{state.inspect} --#{character};#{pop_character}/#{push_characters}--> #{next_state.insepct}>"
	end
end

class DPDARulebook < Struct.new(:rules)
	def follow_free_move(configuration)
		if applies_to?(configuration, nil)
			follow_free_move(next_configuration(configuration, nil))
		else
			configuration
		end
	end

	def applies_to?(configuration, character)
		!rule_for(configuration, character).nil?
	end

	def rule_for(configuration, character)
		rules.detect { |rule|
			rule.applies_to?(configuration, character)
		}
	end

	def next_configuration(configuration, character)
		rule_for(configuration, character).follow(configuration)
	end
end

class DPDA < Struct.new(:current_configuration, :accept_states, :rulebook)
	def current_configuration
		rulebook.follow_free_move(super)
	end

	def accepting?
		accept_states.include?(current_configuration.state)
	end

	def stuck?
		current_configuration.stuck?
	end

	def next_configuration(character)
		if rulebook.applies_to?(current_configuration, character)
			rulebook.next_configuration(current_configuration, character)
		else
			current_configuration.stuck
		end
	end

	def read_character(character)
		self.current_configuration = next_configuration(character)
	end

	def read_string(string)
		string.chars.each do |character| 
			read_character(character) unless stuck?
		end
	end
end

class DPDADesign < Struct.new(:current_configuration, :accept_states, :rulebook)
	def to_dpda
		DPDA.new(current_configuration, accept_states, rulebook)
	end

	def accepts?(string)
		to_dpda.tap { |dpda| dpda.read_string(string) }.accepting?
	end
end

rulebook = DPDARulebook.new([
	PDARule.new(1, '(', 2, '$', ['b', '$']),
	PDARule.new(2, '(', 2, 'b', ['b', 'b']),
	PDARule.new(2, ')', 2, 'b', []),
	PDARule.new(2, nil, 1, '$', ['$'])
])

stack = Stack.new(['b', 'b', '$'])
state = 2
configuration = PDAConfiguration.new(state, stack)

rulebook.next_configuration(configuration, '(')
rulebook.next_configuration(configuration, ')')

rulebook = DPDARulebook.new([
	PDARule.new(1, '(', 2, '$', ['b', '$']),
	PDARule.new(2, '(', 2, 'b', ['b', 'b']),
	PDARule.new(2, ')', 2, 'b', []),
	PDARule.new(2, nil, 1, '$', ['$'])
])

start_stack = Stack.new(['$'])
start_configuration = PDAConfiguration.new(1, start_stack)
accept_states = [1]

rule = PDARule.new(1, '(', 2, '$', ['b', '$'])
rule.follow(start_configuration)

dpda = DPDA.new(start_configuration, accept_states, rulebook)
dpda.read_string('())')
dpda.current_configuration
dpda.accepting?
dpda.stuck?

dpda_design = DPDADesign.new(start_configuration, accept_states, rulebook)
dpda_design.accepts?('()')
dpda_design.accepts?('(()))')
