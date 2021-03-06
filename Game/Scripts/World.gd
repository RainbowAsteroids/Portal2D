extends Node2D

const offset = Vector2(32,0) #Size of the TileMap
onready var aspect_zoom = camera_zoom * Vector2(1024 / get_viewport().size.x, 600 / get_viewport().size.y)
onready var zooms = {
	false: aspect_zoom,
	true: Vector2(1,1)
}

export(PackedScene) var Bullet
export(PackedScene) var Portal
export(float) var bullet_speed = 500
export(float) var teleport_delay = .5

export(Vector2) var camera_offset
export(Vector2) var camera_zoom = Vector2(1,1)

var type = 'peaceful'

var subsitute_data = {'world_num':0,'last_world':0}

const save_file = 'user://save.json'

func pause():
	get_tree().paused = not get_tree().paused
	$Container.visible = get_tree().paused
	$Player/Camera2D.zoom = zooms[get_tree().paused]

func _process(_delta):
	$Container.position = $Player.global_position - (get_viewport().size / 2)

func _input(event):
	if Input.is_action_just_pressed('pause'):
		pause()

func _ready():
	#Save whatever level we're on
	$"Container/Pause Menu".rect_size = get_viewport().size
	
	var world_num = int(filename[18])
	
	PlayerVars.last_world = world_num
	
	if File.new().file_exists(save_file):
		var file = File.new()
		file.open(save_file, File.READ_WRITE)
		var data = parse_json(file.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			data = subsitute_data
		if data['world_num'] < world_num: data['world_num'] = world_num
		file.store_string(to_json(data))
		file.close()
	else:
		var file = File.new()
		file.open(save_file, File.WRITE)
		file.store_string(to_json({'world_num':world_num}))
		file.close()
	
	#Set the camera settings
	$'Player/Camera2D'.offset = camera_offset
	$'Player/Camera2D'.zoom = aspect_zoom
	
	#Connect a signal will all of the killzones
	for node in get_children():
		if node.get_class() == 'Area2D' and node.type == 'killzone':
			node.connect('kill_player', self, 'restart')
	
	$"Container/Pause Menu".connect("unpause", self, "_on_Pause_Menu_unpause")

func restart():
	get_tree().change_scene('res://UIs/DeathScreen.tscn')

func adjecent_tile(vert, map, pos):
	var add
	if vert: add = [Vector2(0,1), Vector2(0,-1)]
	else: add = [Vector2(1,0), Vector2(-1,0)]
	
	var return_value = false
	for offset in add:
		return_value = return_value or (map.get_cellv(pos+offset) != map.INVALID_CELL)
	
	return return_value
	

var colors = [
	Color(0,1,1), # Portal 0: cyan
	Color(1,0.3568,0.2) # Portal 1: orange
]

var portals = [null, null]
func _on_Player_shoot(direction, exit_position, type):
	var bullet = Bullet.instance()
	bullet.position = exit_position
	bullet.rotation = direction
	bullet.velocity = Vector2(bullet_speed, 0).rotated(direction)
	bullet.type = type
	bullet.modulate = colors[type]
	bullet.connect('make_portal', self, '_on_PortalBullet_make_portal')
	
	add_child(bullet)

func _on_PortalBullet_make_portal(position, type, side):
	var preserved = side
	var positions = {
		-90:[Vector2(-32,0),Vector2(0,0),Vector2(32,0)], 270:[Vector2(-32,0),Vector2(0,0),Vector2(32,0)],
		90:[Vector2(-32,0),Vector2(0,0),Vector2(32,0)],
		0:[Vector2(0,-32),Vector2(0,0),Vector2(0,32)], 360:[Vector2(0,-32),Vector2(0,0),Vector2(0,32)],
		180:[Vector2(0,-32),Vector2(0,0),Vector2(0,32)]
	}
	
	var tile_map = get_node('TileMap')
	
	if portals[type] == null:
		portals[type] = []
		for i in range(3):
			var portal = Portal.instance()
			portal.rotation_degrees = side
			portal.type = type
			portal.modulate = colors[type]
			portal.position = position+positions[side][i]
			portals[type].append(portal)
			var tile = tile_map.world_to_map(portal.position)
			if (adjecent_tile(true, tile_map, tile) and adjecent_tile(false, tile_map, tile)): # If this isn't a corner
				continue
			portal.connect('teleport_player', self, '_on_Portal_teleport_player')
			add_child(portal)
	else: 
		for portal in portals[type]:
			portal.queue_free()
		portals[type] = null
		_on_PortalBullet_make_portal(position, type, preserved)

func _on_Portal_teleport_player(portal, type, body):
	body.call_track += 1
	
	if body.portal_des != 2: return # Can we teleport?
	
	var des_type = int(not bool(type))
	var des_portals = portals[des_type]
	var portal_index = portals[type].find(portal)
	if des_portals == null: return
	portal = des_portals[portal_index]
	
	body.portal_des = des_type
	
	if body.type == 'player':
		body.position = portal.position + offset.rotated(portal.rotation)
	elif body.type == 'enemy':
		body.position = portal.position + (offset*2).rotated(portal.rotation)
		body.linear_velocity.y = 300

func _on_Pause_Menu_unpause():
	pause()
