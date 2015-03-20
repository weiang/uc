require 'set'

class FARule < Struct.new(:state, :character, :next_state)
	def applies_to?(state, character)
		self.state == state && self.character == character
	end

	def follow
		next_state
	end

	def inspect
		"#<FARule #{state.inspect} --#{character}--> #{next_state.inspect}>"
	end
end

class NFARulebook < Struct.new(:rules)
	def next_states(states, character)
		states.flat_map { |state| follow_rules_for(state, character) }.to_set
	end

	def follow_rules_for(state, character)
		rules_for(state, character).map(&:follow)
	end

	def rules_for(state, character)
		rules.select { |rule| rule.applies_to?(state, character) }
	end

	def follow_free_moves(states)
		more_states = next_states(states, nil)
		if more_states.subset?(states)
			states
		else
			follow_free_moves(states+more_states)
		end
	end
end

class NFA < Struct.new(:current_states, :accept_states, :rulebook)
	def current_states
		rulebook.follow_free_moves(super)
	end

	def accepting?
		(current_states & accept_states).any?
	end

	def read_char(char)
		self.current_states = rulebook.next_states(current_states, char)
	end

	def read_string(string)
		string.chars.each { |char| read_char(char) }
	end
end

rulebook = NFARulebook.new([
	FARule.new(1, 'a', 1), FARule.new(1, 'b', 1), FARule.new(1, 'b', 2),
	FARule.new(2, 'a', 3), FARule.new(2, 'b', 3),
	FARule.new(3, 'a', 4), FARule.new(3, 'b', 4)
])

rulebook.next_states(Set[1], 'b')
rulebook.next_states(Set[1, 2], 'a')
rulebook.next_states(Set[1, 3], 'b')

class NFADesign < Struct.new(:start_state, :accept_states, :rulebook)
	def accepts?(string)
		to_nfa.tap { |nfa| nfa.read_string(string) }.accepting?
	end

	def to_nfa
		NFA.new(Set[start_state], accept_states, rulebook)
	end
end

rulebook = NFARulebook.new([
	FARule.new(1, nil, 2), FARule.new(1, nil, 4),
	FARule.new(2, 'a', 3), 
	FARule.new(3, 'a', 2),
	FARule.new(4, 'a', 5),
	FARule.new(5, 'a', 6),
	FARule.new(6, 'a', 4)
])

rulebook.next_states(Set[1], nil)

rulebook.follow_free_moves(Set[1])

nfa_design = NFADesign.new(1, [2, 4], rulebook)
nfa_design.accepts?('aa')
nfa_design.accepts?('aaa')
nfa_design.accepts?('aaaa')
nfa_design.accepts?('aaaaa')

module Pattern
	def bracket(outer_precedence)
		if precedence < outer_precedence
			'(' + to_s + ')'
		else
			to_s
		end
	end

	def inspect
		"/#{self}/"
	end

	def matches?(string)
		to_nfa_design.accepts?(string)
	end
end

class Empty
	include Pattern

	def to_s
		''
	end

	def precedence
		3
	end
end

class Literal < Struct.new(:character)
	include Pattern

	def to_s
		character
	end

	def precedence
		3
	end
end

class Concatenate < Struct.new(:first, :second)
	include Pattern

	def to_s
		[first, second].map { |pattern| pattern.bracket(precedence) }.join
	end

	def precedence
		1
	end
end

class Choose < Struct.new(:first, :second)
	include Pattern

	def to_s
		[first, second].map { |pattern| pattern.bracket(precedence) }.join('|')
	end

	def precedence
		0
	end
end

class Repeat < Struct.new(:pattern)
	include Pattern

	def to_s
		pattern.bracket(precedence) + '*'
	end

	def precedence
		2
	end
end

pattern = 
	Repeat.new(
		Choose.new(
			Concatenate.new(Literal.new('a'), Literal.new('b')),
			Literal.new('a')
		)
	)

# to_nfa_design

class Empty
	def to_nfa_design
		start_state = Object.new
		accept_states = [start_state]	
		rulebook = NFARulebook.new([])

		NFADesign.new(start_state, accept_states, rulebook)
	end
end

class Literal
	def to_nfa_design
		start_state = Object.new
		accept_state = Object.new
		accept_states = [accept_state]

		rules = [FARule.new(start_state, character, accept_state)]
		rulebook = NFARulebook.new(rules)

		NFADesign.new(start_state, accept_states, rulebook)
	end
end

class Concatenate
	def to_nfa_design
		nfa1 = first.to_nfa_design
		nfa2 = second.to_nfa_design

		start_state = nfa1.start_state
		accept_states = nfa2.accept_states

		rules = nfa1.rulebook.rules + nfa2.rulebook.rules
		extra_rules = nfa1.accept_states.map { |state|
			FARule.new(state, nil, nfa2.start_state)
		}
		rulebook = NFARulebook.new(rules + extra_rules)

		NFADesign.new(start_state, accept_states, rulebook)
	end
end

class Choose
	def to_nfa_design
		nfa1 = first.to_nfa_design
		nfa2 = second.to_nfa_design

		start_state = Object.new
		accept_states = nfa1.accept_states + nfa2.accept_states

		rules = nfa1.rulebook.rules + nfa2.rulebook.rules
		extra_rules = [nfa1.start_state, nfa2.start_state].map { |state|
			FARule.new(start_state, nil, state)
		}
		rulebook = NFARulebook.new(rules + extra_rules)

		NFADesign.new(start_state, accept_states, rulebook)
	end
end

class Repeat
	def to_nfa_design
		nfa = pattern.to_nfa_design

		start_state = Object.new
		accept_states = nfa.accept_states + [start_state]

		extra_rules = 
			nfa.accept_states.map { |state|
				FARule.new(state, nil, nfa.start_state)
			} +
			[FARule.new(start_state, nil, nfa.start_state)]
		rules = nfa.rulebook.rules
		rulebook = NFARulebook.new(rules + extra_rules)

		NFADesign.new(start_state, accept_states, rulebook)
	end
end


Empty.new.matches?('a')
Literal.new('a').matches?('a')
pattern.matches?('abb')
pattern.matches?('aba')
