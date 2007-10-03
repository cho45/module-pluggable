
class Test
	def init(parent)
		@parent = parent
	end

	def say
		"I'm #{self.class} plugin of #{@parent}."
	end
end
