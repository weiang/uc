require 'set'
require './dfa'

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
	def alphabet
		rules.map(&:character).compact.uniq
	end

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

	def to_nfa(current_states = Set[start_state])
		NFA.new(current_states, accept_states, rulebook)
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

class NFASimulation < Struct.new(:nfa_design)
	def to_dfa_design
		start_state = nfa_design.to_nfa.current_states
		states, rules = discover_states_and_rules(Set[start_state])
		accept_states = states.select { |state| nfa_design.to_nfa(state).accepting? }
		
		DFADesign.new(start_state, accept_states, DFARulebook.new(rules))
	end

	def next_state(state, character)
		nfa_design.to_nfa(state).tap { |nfa|
			nfa.read_char(character)
		}.current_states
	end

	def rules_for(state)
		nfa_design.rulebook.alphabet.map { |character|
			FARule.new(state, character, next_state(state, character))
		}
	end

	def discover_states_and_rules(states)
		rules = states.flat_map { |state|
			rules_for(state)
		}
		more_states = rules.map(&:follow).to_set	

		if more_states.subset?(states)
			[states, rules]
		else
			discover_states_and_rules(states + more_states)
		end
	end
end

rulebook = NFARulebook.new([
	FARule.new(1, 'a', 1), FARule.new(1, 'a', 2), FARule.new(1, nil, 2),
	FARule.new(2, 'b', 3), 
	FARule.new(3, 'b', 1), FARule.new(3, nil, 2)
])

nfa_design = NFADesign.new(1, [3], rulebook)
nfa_design.to_nfa(Set[3]).current_states

simulation = NFASimulation.new(nfa_design)
simulation.next_state(Set[1], 'a')

rulebook.alphabet
simulation.rules_for(Set[1, 2])
start_state = nfa_design.to_nfa.current_states
simulation.discover_states_and_rules(Set[start_state])

dfa_design = simulation.to_dfa_design
dfa_design.accepts?('aaa')
dfa_design.accepts?('aab')
dfa_design.accepts?('bbbabb')
