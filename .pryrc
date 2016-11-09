# Change encoding when writing command history
#Pry.history.instance_eval do
#   @saver = ->(line) { save_to_file (line.force_encoding(STDIN.external_encoding))}
#end

# Hit Enter to repeat last command 
Pry::Commands.command /^$/, "repeat last command" do 
  _pry_.run_command Pry.history.to_a.last 
end

Pry.commands.alias_command 's', 'step' 
Pry.commands.alias_command 'n', 'next' 
Pry.commands.alias_command 'f', 'finish' 
Pry.commands.alias_command 'c', 'continue' 
