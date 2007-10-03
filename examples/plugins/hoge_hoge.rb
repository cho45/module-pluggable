
class HogeHoge
	def init(parent)
		@parent = parent
	end

	def say
		"Hehe, I'm #{self.class} plugin of #{@parent}."
	end
end
