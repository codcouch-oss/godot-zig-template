extends Node

func _ready():
	var hello = HelloNode.new()
	hello.say_hello()
	hello.greeting_count = 42
	print("greeting_count = ", hello.greeting_count)
	hello.queue_free()
