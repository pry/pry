require 'pry'

binding_num = 2

loop do
  b    = binding.of_caller binding_num
  iseq = b.instance_variable_get("@iseq")

  if iseq.path[/kernel_require\.rb$/] and iseq.label == "require" # find the require method
    binding.of_caller(binding_num + 1).pry # (the next binding is the caller of require)
    break
  end

  binding_num += 1 # keep looking!
end
