/**
	FUTURE KNIGHT MAP OBJECT
	========================
	
	
	- Loads and Creates the TileMap
	- Handles camera scrolling
	- Reads room entities and pushes them to user for creation
	- Follows Player (from Reg.st.player global) and scrolls rooms
	- Offers some tile checks functions to be used from Sprites
	
	
	- EXIT HANDLER 
		. handle exits
	
	DEBUG:
	========
	
	- Press (SHIFT + DIRECTION) to scroll to new rooms
	- Press (SHIFT + MOUSE) to position player
	
	
	LAYERS
	======
	0: Background
	1: Shadows
	2: FG Tiles / Collision
	
	
**/


package;

import MapTiles.FG_TILE_TYPE;
import MapTiles.EDITOR_TILE;
import djA.DataT;

import gamesprites.Item.ITEM_TYPE;
import gamesprites.AnimatedTile;
import gamesprites.Player;

import tools.TilemapGeneric;

import djA.types.SimpleCoords;
import djfl.util.TiledMap.TiledObject;
import djFlixel.D;
import djFlixel.core.Dcontrols.DButton;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.tile.FlxTilemap;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.VarTween;

import haxe.EnumTools;


enum MapEvent 
{
	scrollStart;
	scrollEnd;
	roomEntities(v:Array<TiledObject>);	// Pushes ALL tiledObject the room has, even player
	loadMap;
}//---------------------------------------------------;


class MapFK extends TilemapGeneric
{
	// :: Do not touch
	public static inline var MAP_SPACE = 0;
	public static inline var MAP_FOREST = 1;
	public static inline var MAP_CASTLE = 2;
	static inline var TILE_SIZE = 8;
	static inline var MAP_ASSET_PATH = "map/";
	static inline var MAP_REAL_PATH  = "assets/maps/";	// used in DYN_ASSETS
	static inline var MAP_EXT = ".tmx";
	
	static inline var SHADOW_ALPHA = 0.5;
	
	// The layer names as declared in TILED 
	static inline var LAYER_BG 			= 'Background';
	static inline var LAYER_APPEND 		= 'Append';
	static inline var LAYER_PLATFORM 	= 'Platforms';
	static inline var LAYER_ENTITIES 	= 'Entities';
	
	// DEV: 8 BIG tiles (easier to grasp) Every big tile is 4 normal tiles
	inline static var ROOM_TILE_WIDTH:Int  = 8 * 4;	// How many tiles make up a room view
	inline static var ROOM_TILE_HEIGHT:Int = 4 * 4;	// How many tiles make up a room view
	
	static inline var DRAW_START_X:Int = 32;  	// Pixels from screen left to draw map
	static inline var DRAW_START_Y:Int = 26;  	// Pixels from screen top to draw map
	
	// :: CAMERA
	static var CAMERA_TRANSITION_TIME = 0.23;
	static var CAMERA_EASE:EaseFunction = FlxEase.smootherStepOut;
	
	public var ROOM_WIDTH  = TILE_SIZE * ROOM_TILE_WIDTH; 
	public var ROOM_HEIGHT = TILE_SIZE * ROOM_TILE_HEIGHT; 
	
	// How many rooms on the x/y axis
	public var roomTotal(default, null):SimpleCoords;
	// Current room the camera is in. STARTING from (0,0) for the top-left
	public var roomCurrent(default, null):SimpleCoords;
	// Current room tile coordinets of top left corner. Useful in enemy AI tile collisions
	public var roomCornerTile(default, null):SimpleCoords;
	// Current room pixel coordinates of the top left corner.
	public var roomCornerPixel(default, null):SimpleCoords;
	
	// #USER SET, MUST BE SET
	public var onEvent:MapEvent->Void;
	
	// Pixel Coordinates of the player
	// Can be null if the current map does not have a start point
	public var PLAYER_SPAWN(default, null):SimpleCoords;
	
	var tweenCamera:VarTween;
	
	// Set this to load the appropriate BG+FG Tiles
	public var MAP_NAME = "";		// Game map name . e.g. "Control Room", This is read from the tmx file
	var MAP_TYPE = 0;				// 0:Space, 1:Forest, 2:Castle. Used in controlling graphic and tile properties
	
	var MAP_FILE = "";		// The short name of the loaded map. e.g. "level_01"
	var MAP_COLOR = "";		// Color id, check "ImageAssets.D_COL_NAME"
	var MAP_COLOR_FG = "";	// ladder colors
	
	var MAP_LOADED_ID = "";	// Combo of MAP:EXIT of the current map loaded.
	
	// Pointer? of all the exit TileObjects in this map
	// ExitName->TiledObject
	var EXITS:Map<String,TiledObject>;
	
	// All unlocked exits throughout the game
	// < "LEVEL:EXIT_NAME" >
	var GLOBAL_EXITS_UNLOCKED:Array<String>;
	
	// Name of MAPs that have their "append" layer unlocked
	// Shortname "level_02"
	var APPLIED_APPENDS:Array<String>;	
	
	// Shadow tile data, constructed from FG tiles when loading the map
	var sh_data:Array<Int>;
	
	
	#if debug
		public static var LAST_LOADED = "";
	#end
	
	//====================================================;
	
	public function new() 
	{
		super(3);	// Two layers, BG and Platforms
		
		// - New camera for the map, also this is now the default camera for everything
		var C = new FlxCamera(DRAW_START_X * 2, DRAW_START_Y * 2, ROOM_WIDTH, ROOM_HEIGHT);
		camera = C;
		FlxG.cameras.add(C);
		FlxCamera.defaultCameras = [C];	// < Make all sprites to only draw on that camera
		
		roomTotal = new SimpleCoords();
		roomCurrent = new SimpleCoords();
		roomCornerTile = new SimpleCoords();
		roomCornerPixel = new SimpleCoords();
		
		_tiledParams = {
			object_tiles_to_center_points:true
		}
		
		GLOBAL_EXITS_UNLOCKED = [];
		APPLIED_APPENDS = [];
	}//---------------------------------------------------;

	
	/** This is the one you should call when loading a level
	 @param DATA "A:B" 
		A , Not a full asset, but rather the shortname of the map file. e.g. "level_02"
		B , exitName If Defined will spawn player to that exit. Else a spawnpoint should be set
	 */
	public function loadMap(DATA:String)
	{
		// e.g. "level_02:B"
		// d[0] = Map short name | d[1] = Exit name
		var d  = DATA.split(':');
		
		MAP_FILE = d[0];
		MAP_LOADED_ID = DATA;
	
		// From map short name to full asset path
		// e.g. "level_02" -> "maps/level_02.tmx";
		var assetPath = MAP_ASSET_PATH + d[0] + MAP_EXT;
		
		#if (debug && DYN_ASSETS)
		
			// on (F12) load this map
			LAST_LOADED = MAP_LOADED_ID;
			
			D.assets.getTextFile(MAP_REAL_PATH + d[0] + MAP_EXT, (mapData)->{
				load(mapData, true);
						// DEV:
						// Hacky way to make global killed objects work on dynamic assets
						// This is copy-pasted from <TileMapGeneric.hx>
						@:privateAccess T.assetLoaded = assetPath;
						for (i in _killed_global) {
							if (i.indexOf(T.assetLoaded) == 0){
								var d = i.split(":");
								_killed.push(Std.parseInt(d[1]));
							}
						}
				
					// :: This code is the same as the one below -----------
					if (d[1] != null)  {
						var exit = EXITS.get(d[1]);
						if (exit == null) throw 'Exit Name : ${d[1]} does not exist in Map ${d[0]}';
						PLAYER_SPAWN = new SimpleCoords(cast exit.x, cast exit.y);
					}else {
						if (PLAYER_SPAWN == null) throw 'Forgot to specify a player spawn point';
					}
					if (APPLIED_APPENDS.indexOf(MAP_FILE) >= 0) appendMap();
					onEvent(MapEvent.loadMap);
					// -----------------------------------------------------
			});
		
		#else
			
			// Release: Load map from static assets
			load(assetPath);
			
			if (d[1] != null) {
				var exit = EXITS.get(d[1]);
				PLAYER_SPAWN = new SimpleCoords(cast exit.x, cast exit.y);
			}
			// Check if map has unlocked section and apply it
			if (APPLIED_APPENDS.indexOf(MAP_FILE) >= 0) appendMap();
			
			// Notify main that the map is ready
			onEvent(MapEvent.loadMap);
		
		#end
	}//---------------------------------------------------;

	
	/** Don't call this from main, use loadLevel(),
	    Call this directly when you want to load a map array (debugging)
		! NOTE !
		- Does not call `onEvent(MapEvent.loadMap)` need to call it later
	 */
	@:noCompletion
	override public function load(S:String, asData:Bool = false)
	{
		// It was scrolling -- not supposed to -- but check anyway
		if (tweenCamera != null) {tweenCamera.cancel(); tweenCamera = null; }	
		
		super.load(S, asData);
		
		MAP_TYPE = T.properties.TYPE;
		MAP_NAME = T.properties.NAME;
		MAP_COLOR = 'bg_' + DataT.existsOr(T.properties.COLOR, 'yellow');
		MAP_COLOR_FG = 'bg_' + DataT.existsOr(T.properties.COLOR_FG, 'blue');
		
		_scanProcessTiles();	// <- Read FG tiles
		 
		// Layer 0 : Background
		// Layer 1 : Shadows (optional)
		// Layer 2 : Foreground Tiles
		
		layers[0].loadMapFromArray(T.getLayer(LAYER_BG), T.mapW, T.mapH,
			Reg.IM.getMapTiles(MAP_TYPE, "bg", MAP_COLOR),
			T.tileW, T.tileH, null, 1, 1, 1);
			
		// Forest has no shadows
		if (MAP_TYPE == MAP_FOREST) {
			layers[1].visible = false;
		}else{
			layers[1].visible = true;
			layers[1].alpha = SHADOW_ALPHA;	
			layers[1].loadMapFromArray(sh_data, T.mapW, T.mapH,
				Reg.IM.STATIC.tiles_shadow,
				T.tileW, T.tileH, null, 1, 1, 1);
		}
		
		layers[2].loadMapFromArray(T.getLayer(LAYER_PLATFORM), T.mapW, T.mapH,
			Reg.IM.getMapTiles(MAP_TYPE, "fg", MAP_COLOR_FG),
			T.tileW, T.tileH, null, 1, MapTiles.FG_START_DRAW[MAP_TYPE], 1);
			
			
		_setTileProperties();	// <- Declare tile collision properties
		
		_scanProcessEntities();	// <- Figure out exits and player spawn points
		
		// -- Init POST things,
		roomTotal.set(Math.floor(T.mapW / ROOM_TILE_WIDTH), Math.floor(T.mapH / ROOM_TILE_HEIGHT));
		roomCurrent.set( -1, -1);	// -1 allows it to be inited later when requested to go to 0,0
		
		// -- INFO and DEV CHECKS
		#if debug
			trace(' === Loaded Map : "$MAP_LOADED_ID"');
			trace(' . TYPE: $MAP_TYPE, NAME: $MAP_NAME');
			trace(' . MAP : Rooms Total ' , roomTotal);
			trace(' . MAP : Rooms Current ' , roomCurrent);
			trace(' . MAP COLORS', MAP_COLOR, MAP_COLOR_FG);
			//T.debug_info();
			trace('--------------------------------------');
		#end
	}//---------------------------------------------------;
	
	
	// -- Called when a room changes and pushes data to user
	function roomcurrent_pushEntities()
	{
		// Get ALL tiles from this area
		// -automatic- does not get entities in the KILLED Array
		var batch = get_objectTilesAt (
			LAYER_ENTITIES, 
			roomCurrent.x  * ROOM_WIDTH, 
			roomCurrent.y  * ROOM_HEIGHT, 
			ROOM_WIDTH, 
			ROOM_HEIGHT
			);
			
		onEvent(MapEvent.roomEntities(batch));	// Pushes out to user the new entities of the new room
	}//---------------------------------------------------;
	
	/**
	   - Set roomCurrent var
	   @param	x Room Coords, 0 index
	   @param	y Room Coords, 0 index
	   @return
	**/
	function roomcurrent_set(x:Int, y:Int):Bool
	{
		if (x < 0) x = 0; else if(x>=roomTotal.x) x=roomTotal.x-1;
		if (y < 0) y = 0; else if(y>=roomTotal.y) y=roomTotal.y-1;
		if (roomCurrent.isEqualWith(x, y)) return false;	// Already there
		roomCurrent.set(x, y);
		roomCornerTile.set(ROOM_TILE_WIDTH * x, ROOM_TILE_HEIGHT * y);
		roomCornerPixel.set(roomCurrent.x * ROOM_WIDTH, roomCurrent.y * ROOM_HEIGHT);
		return true;
	}//---------------------------------------------------;
	
	/**
	   Move camera to the room position containing a (X,Y) coords
	**/
	public function camera_teleport_to_room_containing(x:Float, y:Float)
	{
		camera_teleport_to_room(Std.int(x / ROOM_WIDTH), Std.int(y / ROOM_HEIGHT));
	}//---------------------------------------------------;
	
	/**
		Snap Camera to ROOM COORDINATES. (0,0) for top left room
	*/
	public function camera_teleport_to_room(x:Int, y:Int)
	{
		if (roomcurrent_set(x, y))
		{
			camera.scroll.set( roomCurrent.x * ROOM_WIDTH, roomCurrent.y * ROOM_HEIGHT);
			roomcurrent_pushEntities();
		}
	}//---------------------------------------------------;
	
	
	/**
	   Scroll camera to RELATIVE ROOM COORDINATES
	   (1,0) will move 1 to the right. (0,-1) will move one above
	**/
	public function camera_move_rel(x:Int = 0, y:Int = 0):Bool
	{
		if (roomcurrent_set(roomCurrent.x + x, roomCurrent.y + y))
		{
			if (tweenCamera != null){
				tweenCamera.cancel();
			}
			onEvent(MapEvent.scrollStart);
			roomcurrent_pushEntities();
			tweenCamera = FlxTween.tween(camera.scroll, {
				x:roomCurrent.x * ROOM_WIDTH,
				y:roomCurrent.y * ROOM_HEIGHT,
			}, CAMERA_TRANSITION_TIME, {
				ease:CAMERA_EASE,
				onComplete:_on_camera_tween_end
			});
			return true;
		}
		return false;
	}//---------------------------------------------------;
	
	
	
	function _on_camera_tween_end(t:FlxTween)
	{
		tweenCamera = null;
		onEvent(MapEvent.scrollEnd);
		
		#if debug
			// Place player
			if (!Reg.st.player.alive)
			{
				for (tx in 0...ROOM_TILE_WIDTH)
				for (ty in 0...ROOM_TILE_HEIGHT)
				{
					if (getCol(roomCornerTile.x + tx, roomCornerTile.y + ty) == 0)
					{
						Reg.st.player.spawn((roomCornerTile.x + tx) * TILE_SIZE, (roomCornerTile.y + ty) * TILE_SIZE);
						return;
					}
				}
			}
		#end
		
		// DEV:
		// User responsible to freeeze/unfreeze, kill/reapawn
	}//---------------------------------------------------;

	
	// -- Called after loading the map and before creating the map
	// + Process HAZARD tiles and make them entities
	// + Process/Create Shadow tiles based
	@:dce
	function _scanProcessTiles()
	{
		sh_data = [];
		
		var data = T.getLayer(LAYER_PLATFORM);
		var hazardIndex = MapTiles.TILE_COL[MAP_TYPE][HAZARD_TILE][0];
		var i = 0;
		var prev = 0; // Keep the previous processed tile
		
		while (i < data.length)
		{

			if (data[i] == hazardIndex) {
				// Create a new TiledObject, put it with the others
				var coords = serialToTileCoords(i);
				T.objects[0].push({
					x:coords.x * T.tileW,
					y:coords.y * T.tileH,
					id:hazardIndex,	// This does not matter right now. So I am putting whatever
					gid:MapTiles.EDITOR_HAZARD
				});
				// Delete the actual tiles
				// DEV: This is fine since the map is read left to right
				data[i]   = 0;
				data[i+1] = 0;
				data[i+2] = 0;
				data[i+3] = 0;
				i += 4;	// The next 3 tiles are hazard, so don't check
				prev = 0;
				continue;
			}
			
			// :: Scan and Create Shadows
			// Skip (Forest)
			// Skip (0,1)
			// Skip Ladder Tiles
			//
			if (
			MAP_TYPE == MAP_FOREST ||
			data[i] < 2 || 
			MapTiles.fgTileIsType(data[i], MAP_TYPE, FG_TILE_TYPE.LADDER))
			{
				prev = 0;
				i++;
				continue;
			}
			
			// > At this point, tile cannot be (empty,ladder,hazard)
			//   so it is a solid block that casts shadow
			
			
			if (prev == 0 && data[i + T.mapW] < 2)
			{
				sh_data[i + T.mapW] = 3;	// (3) is start of shadow tile gfx
			}
			
			// Don't process edge of the map
			if ((i % T.mapW) < T.mapW - 1)
			{
				var SL = 0;
				
				if (MAP_TYPE == MAP_SPACE) // Slides only exist in spacestation
				if (MapTiles.fgTileIsType(data[i], MAP_TYPE, FG_TILE_TYPE.SLIDE_RIGHT)) SL = 1;
	
				if (data[i + 1] < 2 && SL == 0)
				{
					sh_data[i + 1] = 1;
				}
				
				// Place the normal shadow at +1+1 offset
				if (data[i + T.mapW + 1] < 2)
				{
					sh_data[i + T.mapW + 1] = 1 + SL;
				}
			}

			prev = data[i];
			i++;
		}
	}//---------------------------------------------------;
	
	
	
	
	// -- Scan the room for entities and process them
	// Mainly for <player spawn>
	function _scanProcessEntities()
	{
		PLAYER_SPAWN = null;
		EXITS = [];
		
		for (i in T.getObjLayer(LAYER_ENTITIES))
		{
			if (i.gid == MapTiles.EDITOR_ENTITY[PLAYER][0]) // the player GID
			{
				PLAYER_SPAWN = new SimpleCoords(cast i.x, cast i.y);
			}else
			
			if (i.gid == MapTiles.EDITOR_EXIT)
			{
				EXITS.set(i.name, i);
			}
		}
	}//---------------------------------------------------;
		
	
	// -- Declare tile collision data to tiles in the foreground player
	function _setTileProperties()
	{
		var m = layers[COLLISION_LAYER];
		var C = MapTiles.TILE_COL[MAP_TYPE];
		

		// Notes:
		// . Declaring SOLIDS is not needed, everytile is solid by default
		// . Animated hazard tiles, not needed, they are converted to Entities
		m.setTileProperties(C[SOFT][0], FlxObject.CEILING, null, null, C[SOFT][1]);
		m.setTileProperties(C[LADDER][0], FlxObject.NONE, null, null, C[LADDER][1]);
		m.setTileProperties(C[LADDER_TOP][0], FlxObject.CEILING, null, null, C[LADDER_TOP][1]);
		
		if (MAP_TYPE == MAP_SPACE)
		{
			m.setTileProperties(C[SLIDE_LEFT][0], FlxObject.ANY, _tilecol_slide_left, null, C[SLIDE_LEFT][1]);
			m.setTileProperties(C[SLIDE_RIGHT][0], FlxObject.ANY, _tilecol_slide_right, null, C[SLIDE_RIGHT][1]);
		}
		
	}//---------------------------------------------------;
	
	
	// DEV: Two versions of <_tilecol_slide> because I don't want to recalculate (LEFT/RIGHT) later
	// -- Send player a slide collision event
	function _tilecol_slide_left(a:FlxObject,b:FlxObject)
	{
		if (Std.is(b, Player)) {
			var t = cast (a, flixel.tile.FlxTile);
			Reg.st.player.event_slide_tile(cast a, FlxObject.LEFT);
		}
	}//---------------------------------------------------;
	function _tilecol_slide_right(a:FlxObject,b:FlxObject)
	{
		if (Std.is(b, Player)) {
			var t = cast (a, flixel.tile.FlxTile);
			Reg.st.player.event_slide_tile(cast a, FlxObject.RIGHT);
		}
	}//---------------------------------------------------;	
	
	
	override public function update(elapsed:Float):Void 
	{
		super.update(elapsed);
	
		// The camera is currently scrolling.
		if (tweenCamera != null) return;
		
		#if debug
			_update_debug();
			if (!Reg.st.player.alive) return;	// Do not track player for debug purposes
		#end
		
		// Camera Track Player ::
		if (Reg.st.player.x + 4 > roomCornerPixel.x + ROOM_WIDTH){
			camera_move_rel(1, 0);
		}else
		if (Reg.st.player.x + 4 < roomCornerPixel.x){
			camera_move_rel( -1, 0);
		}else
		if (Reg.st.player.y + 8 > roomCornerPixel.y + ROOM_HEIGHT){
			camera_move_rel(0, 1);
		}else
		if (Reg.st.player.y + 8 < roomCornerPixel.y){
			camera_move_rel(0, -1);
		}
		
	}//---------------------------------------------------;
	
	/**
	   Check if a sprite went off-view of the current room
	**/
	public function isOffRoom(s:FlxSprite):Bool
	{
		return ( 
			s.x < Reg.st.map.roomCornerPixel.x  ||
			s.x + s.width > Reg.st.map.roomCornerPixel.x + Reg.st.map.ROOM_WIDTH ||
			s.y < Reg.st.map.roomCornerPixel.y ||
			s.y + s.height > Reg.st.map.roomCornerPixel.y + Reg.st.map.ROOM_HEIGHT 
			);
	}//---------------------------------------------------;
	
	
	
	/** Return Y for floor, -1 if not found */
	public function getFloor(x:Int, y:Int):Int
	{
		// Max Search = (8) tiles down
		for (i in 0...8) {
			var y1 = y + i;
			var t = layerCol().getTile(x, y1);	// No check is needed?
			if (t > 0 && (layerCol().getTileCollisions(t) & FlxObject.ANY > 0))
			{
				return y1;
			}
		}
		return -1;	// nothing found
	}//---------------------------------------------------;
	
	
	
	/**
	   Double (2) Ray Cast (casts left-right, or up-down)
	   Cast rays in the tilemap Horizontal, or Vertical, stopping at Any Tile Collision or Empty Tile (CHECK)
	   Useful to calculate The Edges of a platform or the Empty area between walls
	   Also checks for ROOM screen borders and limits inside them
	   @param X In 8x8 tile coords
	   @param Y In 8x8 tile coords
	   @param AxisX True to check for X axis, false to check for Y axis
	   @param CHECK 0 to check Until no Tile, 1 to check Until Any Collision Tile
	   @return {v0,v1} Minimum Maximum in Tiles
	 */
	/// DEV: This is almost ready to be put on the generic class.
	///		  Need to  room limits into consideration? Make it optional or whatever.
	public function get2RayCast(X:Int, Y:Int, AxisX:Bool = true, CHECK:Int = 0):{v0:Int, v1:Int}
	{
		var o = {v0:0, v1:0};
		var B0 = AxisX?roomCornerTile.x:roomCornerTile.y;
		var B1 = AxisX?roomCornerTile.x + ROOM_TILE_WIDTH:roomCornerTile.y + ROOM_TILE_HEIGHT;
		var xx = X;
		var yy = Y;
		var v = 0;
		var i = 1;
		while (true) // Check RIGHT/DOWN
		{
			if (AxisX) v = xx = X + i; else v = yy = Y + i;
			var t = getCol(xx, yy);
			if ((v >= B1) || ( CHECK == 0?t == 0:t > 0)) {
				o.v1 = v; break;
			} i++;
		}	
		
		i = 1; while (true) // Check LEFT/UP
		{
			if (AxisX) v = xx = X - i; else v = yy = Y - i;
			var t = getCol(xx, yy);
			if ((v < B0) || ( CHECK == 0?t == 0:t > 0) ) {
				o.v0 = v + 1; break;
			} i++;
		}
		
		return o;
	}//---------------------------------------------------;
	
	
	/** Get the ENUM type of an FG tile */
	public function tileIsType(id:Int, type:FG_TILE_TYPE):Bool
	{
		var AR = MapTiles.TILE_COL[MAP_TYPE].get(type);
		return (id >= AR[0] && id < AR[0] + AR[1]);
	}//---------------------------------------------------;
	
	/**
	   Get a tile id by Pixel Coordinates */
	public function getTileP(X:Float, Y:Float):Int
	{
		return layers[COLLISION_LAYER].getTile(Std.int(X / T.tileW), Std.int(Y / T.tileH));
	}//---------------------------------------------------;
	
	
	
	
	
	//====================================================;
	// GAME 
	//====================================================;
	
	
	// -- Called by an exit when it is spawned
	public function exit_isLocked(o:TiledObject):Bool
	{
		if (o.prop == null) throw "Exit should have properties defined";
		
		if (o.prop.req == null || o.prop.req == "") return false;
		
		//trace("Checking exit against GLOBAL_EXITS_UNLOCKED");
		//trace(o, GLOBAL_EXITS_UNLOCKED);
		if (GLOBAL_EXITS_UNLOCKED.indexOf(get_exit_uid(o)) >= 0)
		{
			trace("Exit was unlocked from the globals , OK");
			return false;
		}
		
		return true;
	}//---------------------------------------------------;
	
	// - Called from player, pressing up an any exit
	// Note: The animatedTile, has all the data I need to know
	public function exit_activate(e:AnimatedTile)
	{
		trace("-- Activating Exit --", e.type);
		
		var locked = e.type.getParameters()[0];

		if (locked)
		{
			// Check Requirements: 
			var d = cast(e.O.prop.req, String).split(':');
			switch(d)
			{
				case ["item", _ ] :
					var item = EnumTools.createByName(ITEM_TYPE, d[1]);
					var itemName = Game.ITEM_DATA[item].name;
					
					if (Reg.st.HUD.equipped_item != item)
					{
						D.snd.play(Reg.SND.error);
						Reg.st.HUD.set_text2("Requires `" + itemName + "` to unlock");
						return;
					}
					
					GLOBAL_EXITS_UNLOCKED.push(get_exit_uid(e.O));
					
					trace("YOU HAVE THE ITEM. EXIT UNLOCK KNOW", GLOBAL_EXITS_UNLOCKED);
					// Do not return, it will unlock the exit later ->
					
					// Remove the currently selected
					Reg.st.HUD.item_pickup(null);
					Reg.st.HUD.set_text2('Unlocked with ' + itemName);
					
					Reg.st.INV.removeItemWithID(item);
					
					
					D.snd.play(Reg.SND.exit_unlock);
					
					//FlxG.signals.postUpdate.addOnce(()->{
						//loadMap(e.O.prop.goto);
						//D.snd.play(Reg.SND.exit_travel);
					//});
					//
					//return;
						
					
				case _: trace("Error: Syntax Error", d); return;
			}
		}// -- (locked)
		
		
		// :: GOTO EXIT TARGET 
		
		#if debug
			if (e.O.prop.goto == null) {
				trace("Error: No exit target");
				return;
			}
		#end
		
		FlxG.signals.postUpdate.addOnce(()->{
			loadMap(e.O.prop.goto);
			D.snd.play(Reg.SND.exit_travel);
		});
		
	}//---------------------------------------------------;
	
	
	// - Called from player, pressing up on any keyhole
	// Check and processes
	public function keyhole_activate(e:AnimatedTile)
	{
		trace("-- Activating KEYHOLE ");
		
		var item = EnumTools.createByName(ITEM_TYPE, e.O.name);
		#if debug
		if (item == null) throw "Forgot to set keyhole requirement, or name wrong";
		#end
	
		if (Reg.st.HUD.equipped_item != item)
		{
			D.snd.play(Reg.SND.error);
			Reg.st.HUD.set_text2("You can use a " + Game.ITEM_DATA[item].name + " here");
			return;
		}
		
		Reg.st.INV.removeItemWithID(item);
		Reg.st.HUD.item_pickup(null);
	
		killObject(e.O, true);
		e.kill();
		D.snd.play(Reg.SND.item_append);
		Reg.st.map.appendMap(true);	
		Reg.st.flash(15);
	}//---------------------------------------------------;
	
	
		
	
	/**
	   - Append the "APPEND" layer to the current map
	   - also makes it global (optionally)
	   @param save Push it to Global State
	**/
	public function appendMap(save:Bool = false)
	{
		// Make sure it is not already ? no need I guess
		
		var data = T.getLayer(LAYER_APPEND);
		if (data == null) throw '$MAP_FILE does not have a $LAYER_APPEND layer';
		
		for (i in 0...data.length) {
			if (data[i] > 0) {
				layers[2].setTileByIndex(i, data[i], true);
			}
		}
		
		if (save) APPLIED_APPENDS.push(MAP_FILE);
		
		trace(">> Appended Extra Layer Map");

	}//---------------------------------------------------;
	
	/**
	   Remove the "APPEND" layer from the actual map
	   - Every tile the layer had, will turn to 0
	   - USED in the final level, where the boss room needed to be locked and unlocked later
	**/
	public function appendRemove()
	{
		// TODO
		var data = T.getLayer(LAYER_APPEND);
		
		for (i in 0...data.length) {
			if (data[i] > 0) {
				layers[2].setTileByIndex(i, 0, true);
			}
		}		
		
		trace(">> Removed Extra layer map");
	}//---------------------------------------------------;

	
	
		
	// Get a string id of an exit in this map
	// USED IN: GLOBAL_EXITS_UNLOCKED []
	function get_exit_uid(e:TiledObject)
	{
		return MAP_FILE + ':' + e.name;
	}//---------------------------------------------------;
	
	
	#if debug
	
	function _update_debug()
	{
		// Click somewhere to put player there
		
		if (FlxG.keys.pressed.SHIFT)
		{
			//Reg.st.player._teleport(FlxG.mouse.x, FlxG.mouse.y);
			if (FlxG.mouse.justPressed)
			{
				var MP = FlxG.mouse.getWorldPosition(camera);
				trace("Spawning Player at ", MP);
				Reg.st.player.spawn(MP.x, MP.y);
				return;
			}
			
			var vec = {x:0, y:0};
			
			if (D.ctrl.justPressed(DButton.LEFT)) {
				vec.x = -1;
			}else if (D.ctrl.justPressed(DButton.RIGHT)) {
				vec.x = 1;
			}else if (D.ctrl.justPressed(DButton.UP)) {
				vec.y = -1;
			}else if (D.ctrl.justPressed(DButton.DOWN)) {
				vec.y = 1;
			}
			if (camera_move_rel(vec.x, vec.y)){
				Reg.st.player.alive = false; // Skip auto-positioning in update()
			}
		}
		
	}//---------------------------------------------------;
		
	#end
	
	public function SAVE(?IN:Dynamic):Dynamic
	{
		if (IN != null)
		{
			GLOBAL_EXITS_UNLOCKED = IN.unlocked;
			_killed_global = IN.killed;
			APPLIED_APPENDS = IN.appends;
			
		}else{	
			return {
				unlocked: GLOBAL_EXITS_UNLOCKED,
				killed: _killed_global,
				appends: APPLIED_APPENDS,
				levelid: MAP_LOADED_ID // read manually, in statePlay
			};
		}
		
		return null;
	}//---------------------------------------------------;
	
	
}// --