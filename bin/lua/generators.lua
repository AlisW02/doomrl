-- NOTE - the blueprint, storage and constructor are declared here, because core has no notion
-- or how DoomRL generates levels (barrels etc)

core.declare( "register_generator", core.register_storage( "generators", "generator" ) )

core.register_blueprint "generator"
{
	id           = { true,   core.TSTRING },
	weight       = { true,   core.TTABLE },
	min_dlevel   = { false,  core.TNUMBER, 3 },
	min_diff     = { false,  core.TNUMBER, 0 },
	events       = { false,  core.TBOOL, true },
	place_stairs = { false,  core.TBOOL, true },
	place_player = { false,  core.TBOOL, true },
	monsters     = { false,  core.TANY, 1.0 },
	items        = { false,  core.TANY, 1.0 },
	rooms        = { false,  core.TANY },
	barrels      = { false,  core.TBOOL, false },
	fluids       = { false,  core.TANY, false },
	rivers       = { false,  core.TANY, false },
	run          = { true,   core.TFUNC },
	post_run     = { false,  core.TFUNC },
}

function DoomRL.load_generators()

	register_generator "gen_tiled"
	{
		weight     = { [{1,8}] = 100, 50 },
		min_dlevel = 1,
		rooms      = { 4, 10 },
		barrels    = true,
		fluids     = 60,
		rivers     = 60,

		run        = function() 
			generator.generate_tiled()
		end
	}

	register_generator "gen_maze"
	{
		weight     = { 20 },
		monsters   = 1.5,
		items      = 0.8,
		barrels    = true,
		rivers     = 66,
		fluids     = true,

		run        = function() 
			local wall_cell    = generator.styles[ level.style ].wall
			local floor_cell   = generator.styles[ level.style ].floor

			local maze_styles = {
				{granularity = 3, tries = 500, minl = 2, maxl = 4 },
				{granularity = 3, tries = 300, minl = 4, maxl = 12},
				{granularity = 3, tries = 100, minl = 4, maxl = 12},
			}
			local style = table.random_pick( maze_styles )
			for x=1,MAXX do generator.set_cell( coord.new(x,MAXY-1), wall_cell ) end
			generator.maze_dungeon( floor_cell, wall_cell, style.granularity, style.tries, style.minl, style.maxl )

			ui.msg_feel( "This floor's layout feels even more tangled and messy than usual..." )
		end,

		post_run   = function()
			local s = generator.find_coord("stairs")
			local p = player.position
			if s and p:distance( s ) <= player.vision and level:eye_contact( p, s ) then
				ui.msg_feel( "Finally, the exit to this maze!")
			end
		end,
	}

	register_generator "gen_caves"
	{
		weight   = { [{9,24}] = 30, 20 },
		events   = false,
		monsters = 0,
		items    = 0,

		run      = function() 
			generator.generate_caves_dungeon()
		end
	}

	register_generator "gen_caves_2"
	{
		weight     = { 20 },
		min_dlevel = 8,
		min_diff   = 2,
		rooms      = { 4, 12 },
		barrels    = true,

		run      = function() 
			generator.generate_caves_2_dungeon()
		end
	}

	register_generator "gen_arena"
	{
		weight       = { 6 },
		min_dlevel   = 8,
		min_diff     = 2,
		events       = false,
		place_stairs = false,
		place_player = false,
		barrels      = true,
		items        = 0.67,
		monsters     = 0.67,

		run        = function() 
			generator.generate_fluids()
			generator.generate_fluids()
			generator.generate_fluids()

			local center  = coord.new( 38,10 )

			local translation = {
				['.'] = generator.styles[ level.style ].floor,
				['#'] = generator.styles[ level.style ].wall,
				['+'] = generator.styles[ level.style ].door,
				['>'] = "stairs",
				['X'] = "wall",
				['%'] = "rwall",
				['@'] = "gwall",
			}
			generator.place_symmetry_quad( table.random_pick( generator.arena_quad_data ), translation )
			local min  = math.min( math.ceil( level.danger_level / 10 ), 4 )
			local max  = math.min( math.ceil( level.danger_level / 4 ), #(generator.arena_data) ) 
			local scheme = math.random( min, max )
			local tile = generator.tile_new( generator.arena_data[scheme], translation )
			local tdim = tile:get_size_coord()
			local hdim = coord.new( math.floor( tdim.x / 2 ), math.floor( tdim.y / 2 ) )
			generator.tile_place( center - hdim, tile )
			level.light[ area.new( center - hdim, center + hdim ) ][ LFNOSPAWN ] = true
			generator.generate_special_stairs()
		end,

		post_run   = function()
			level:drop_being( player, coord.new( 38,10 ) )
		  	ui.msg_feel( "Suddenly, enemies pour out of hiding from all sides!" )
			for b in level:beings() do
				if math.random(2) == 1 then
					b.flags[ BF_HUNTING ] = true
				end
			end
		end,
	}

	register_generator "gen_warehouse"
	{
		weight      = { 25 },
		barrels     = true,
		fluids      = 30,
		rivers      = 20,

		run       = function() 
			local wall_cell = generator.styles[ level.style ].wall
			local areas     = {}
			local divs      = table.random_pick{ 1, 2, 2, 2, 2, 3 }
			local divpoint  = 1

			for i=1,divs do
				local newdiv = math.floor( MAXX / (divs+1) )*i + math.random(16)-8
				local where = coord.new( newdiv, math.random(12)+4 )
				generator.plot_lines( where, area.FULL, false, wall_cell, generator.cell_set{ wall_cell } )
				generator.set_cell( where, generator.styles[ level.style ].door )
				table.insert( areas, area.new( divpoint+1, 2, newdiv-1, MAXY-1 ) )
				divpoint = newdiv
			end
			table.insert( areas, area.new( divpoint+1, 2, MAXX-1, MAXY-1 ) )

			for _,ar in ipairs(areas) do
				local size = table.random_pick{ 2, 3, 3, 3, 3, 4 }
				local tries = table.random_pick{ 50, 50, 200 }
				if math.random( 3 ) == 1 then
					generator.warehouse_fill( wall_cell, ar, size, tries )
				else
					generator.warehouse_fill( { "crate", "ycrate" }, ar, size, tries, 10, { "crate_ammo", "crate_armor" } )
				end			
			end
		end
	}

	register_generator "gen_archi"
	{
		weight       = { 40 },
		min_dlevel   = 8,
		barrels      = true,
		rivers       = 25,

		run          = function() 
			local wall_cell    = generator.styles[ level.style ].wall
			local translation = {
				["X"] = wall_cell,
				["."] = generator.styles[ level.style ].floor,
				["+"] = generator.styles[ level.style ].door,
			}

			generator.fill( wall_cell )

			local data = table.random_pick{ generator.archi_data, generator.archi_data2 }
			local blocks = data.blocks
			local bsize  = data.size
			local shift  = data.shift 
			for k,v in pairs( data.trans ) do translation[k] = v end

			for bx=1,blocks.x do
				for by=1,blocks.y do
					local block = table.random_pick( data )
					local pos   = coord.new( (bx-1) * (bsize.x-1) + shift.x, (by-1) * (bsize.y-1) + shift.y )
					local tile  = generator.tile_new( block, translation )
					tile:flip_random()
					generator.tile_place( pos, tile )
				end
			end

			for c in generator.each( generator.styles[ level.style ].door ) do
				if generator.cross_around( c, wall_cell ) > 2 then
					generator.set_cell( c, wall_cell )
				end
			end

			generator.restore_walls( wall_cell )
			generator.generate_fluids(area.new(shift.x+1, shift.y+1, MAXX - shift.x-1, MAXY - shift.y-1))
		end,
	}

	register_generator "gen_city"
	{
		weight       = { [{1,8}] = 10, 40 },
		min_dlevel   = 4,
		rooms        = { 4, 12 },
		barrels      = true,
		fluids       = true,

		run          = function() 
			local wall_cell    = generator.styles[ level.style ].wall
			local floor_cell   = generator.styles[ level.style ].floor
			local door_cell    = generator.styles[ level.style ].door

			local tries = 100
			local dim_max = coord.new( 16, 12 )
			local dim_min = coord.new( 7, 6 )
			local city = area.shrinked( area.FULL, 2 )

			if math.random(3) == 1 then	generator.generate_rivers( false, true ) end
		
			for i=1,tries do
				local room = area.random_subarea( city, coord.random( dim_min, dim_max ) )
				if generator.scan(room,floor_cell) then
					room:shrink(1)
					generator.fill( wall_cell, room )
					generator.set_cell( area.random_inner_edge_coord( room ), door_cell )
					room:shrink(1)
					generator.fill( "crate", room )
					generator.add_room( room:expanded() )
				end
			end
			generator.transmute( "crate", floor_cell )
		end
	}

	register_generator "gen_single"
	{
		weight       = { 6 },
		min_dlevel   = 16,
		min_diff     = 2,
		items        = 1.5,
		rooms        = { 4, 10 },
		barrels      = true,
		fluids       = true,

		monsters   = function( bweight )
			local intro = {
				imp        = "The walls around you are covered in slashes and scorch marks...",
				mancubus   = "Deep, gutteral growls and bellows can be heard through the halls...",
				revenant   = "The sound of creaking bones and clattering metal echo around you...",
				arch       = "You can feel a powerful energy from some hellish creature on this floor...",
			}

			local roll    = math.min( level.danger_level + (DIFFICULTY - 2)*3-4, 20) + math.random(10)
			local monster = core.less_than_table( {
					{17,"former"}, {19,"imp"}, {21,"knight"}, {21,"knight"},
					{24,"mancubus"}, {26,"revenant"}, {100,"arch"}
				}, roll )

			if monster == "arch" and math.random(3) == 1 then
				ui.msg_feel( "A powerful demonic energy fills the air!" )
				level:flood_monster{ danger = bweight / 2, id = "arch" }
				level:flood_monsters{ danger = bweight / 2, list = { "captain", "sergeant", "former", "commando" } }
			elseif monster == "knight" then
				ui.msg_feel( "A battlecry in an unknowable demonic language echoes through the halls!" )
				level:flood_monsters{ danger = bweight, list = { "baron", "knight", "bruiser" } }
			elseif monster == "former" then
				ui.msg_feel( "You can hear the familiar rhythm of many marching boots." )
				level:flood_monsters{ danger = bweight, list = { "former", "sergeant", "captain", "commando" } }
				if DIFFICULTY > 3 then
					level:flood_monsters{ danger = bweight / 8, list = { "esergeant", "eformer" } }
				end
				if DIFFICULTY > 4 or level.danger_level > 60 then
					level:flood_monster{ danger = bweight / 8, id = "ecaptain" }
				end
				if level.danger_level > 100 then
					level:flood_monster{ danger = bweight / 8, id = "ecommando" }
				end
			else
				if intro[monster] then
					ui.msg_feel( intro[monster] )
				end
				level:flood_monster{ id = monster, danger = generator.being_weight() }
			end

			player:add_history("Level @1 was infested with "..beings[monster].name_plural.."!")
		end,
		run        = function() 
			generator.generate_tiled()
		end
	}

	register_generator "gen_single_plus"
	{
		weight       = { 1 },
		min_dlevel   = 50,
		min_diff     = 3,
		items        = 2.0,
		rooms        = { 4, 10 },
		barrels      = true,
		fluids       = true,

		monsters   = function( bweight )
			local intro = {
				shambler   = "The air is crackling with electricity, and every hair on your body stands on end!",
				bruiser    = "You hear loud, unholy wailing echo through the halls!",
				cyberdemon = "The ground shakes with the footsteps of something enormous. Or rather, several somethings...",
			}

			local monster = table.random_pick{"cyberdemon","shambler","bruiser"}
			ui.msg_feel( intro[monster] )
			level:flood_monster{ id = monster, danger = generator.being_weight() }
			player:add_history("Level @1 was infested with "..beings[monster].name_plural.."!")
		end,
		run        = function() 
			generator.generate_tiled()
		end
	}

	register_generator "gen_lava"
	{
		weight     = { [{12,20}] = 10, 20 },
		min_dlevel = 12,
		min_diff   = 2,
		rooms      = { 4, 10 },

		run        = function() 
			generator.generate_lava_dungeon()
		end
	}

end
