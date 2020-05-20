package gamesprites;

import djfl.util.TiledMap.TiledObject;
import flixel.FlxSprite;



enum AnimTileType
{
	HAZARD;
	WEAPON(i:Int);
	EXIT(locked:Bool);
	DECO;
	KEYHOLE;
	LASER;	
}


class AnimatedTile extends MapSprite
{
	public var type(default, null):AnimTileType;
	
	public function new() 
	{		
		super();
		Reg.IM.loadGraphic(this, 'animtile');
		animation.add('_HAZARD', [0, 1, 2, 3], 8);
		animation.add('_WEAPON_2', [4, 5, 6, 7], 8);
		animation.add('_WEAPON_3', [8, 9], 8);
		animation.add('_EXIT', [10, 11], 4);
		animation.add('_EXIT_LOCK', [12, 13], 4);
		animation.add('_DECO_5', [14, 15, 16, 17], 7);
		animation.add('_DECO_6', [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 26, 27, 26, 27, 26, 27, 26, 27], 6);
		animation.add('_KEYHOLE_1', [28, 29], 6);
		animation.add('_LASER', [30, 31], 20);
	}//---------------------------------------------------;
	
	override public function spawn(o:TiledObject, gid:Int):Void 
	{
		super.spawn(o, gid);
		
		offset.set(0, 0);
		setSize(32, 32);	// < ReSetting size and offset back to normal
		
		var anim = "";
		switch(gid)
		{
			case 1:
				// NOW it is the time to figure out whether this EXIT is locked or not
				var locked = Reg.st.map.exit_isLocked(o);
				type = AnimTileType.EXIT(locked);
				anim = "_EXIT" + (locked?"_LOCK":"");
				offset.set(0, 8);
				setSize(32, 16);
				spawn_origin_set(1);
			case 2, 3:
				anim = "_WEAPON_" + gid;
				type = AnimTileType.WEAPON(gid - 1);	// id2=>1, id3=>2
				spawn_origin_set(0);
			case 4:
				anim = "_HAZARD";
				type = AnimTileType.HAZARD;
				// Dev: I am making the hazard tile a bit taller to allow tighter collisions 
				// when walking into it from the sides.
				offset.set(0, 15);
				setSize(32, 9);	// 8 pixels is GFX, 1 pixels empty to the top.
				spawn_origin_set(1);
			case 7:
				anim = "_KEYHOLE_" + (gid - 6);
				type = AnimTileType.KEYHOLE;
				setSize(24, 21);
				offset.set(7, 4);
				spawn_origin_set(0);
				
			case 8:
				anim = "_LASER";
				type = AnimTileType.LASER;
				setSize(8, 32);
				offset.set(12, 0);
				spawn_origin_set(0);
				
			case _:
				anim = "_DECO_" + gid;
				type = AnimTileType.DECO;
				spawn_origin_set(0);
		};
		
		// NOTE: You can check enums like this :
		//if(type.match(WEAPON(_)))
		//{
		//  trace("is a weapon");
		//}
		
		animation.play(anim, true);
		spawn_origin_move();
	}//---------------------------------------------------;
	
}// --