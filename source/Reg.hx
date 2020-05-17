package;

import djA.ConfigFile;
import djFlixel.D;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import haxe.Json;
import states.StatePlay;
import states.SubStatePause;


/**
 * Various Parameters
 * - Everything is public
 */
@:publicFields
class Reg 
{
	public static inline var VERSION = "1.5";
	
	// :: Sounds
	
	// :: External parameters
	static inline var PATH_JSON = "assets/djflixel.json";
	static inline var PATH_INI  = "assets/test.ini";
	
	// How long to wait on each screen on the banners
	static inline var BANNER_DELAY:Float = 12;
	//====================================================;
	
	// :: Image Asset Manager
	public static var IM:ImageAssets;

	// This is for quick access to game elements
	public static var st:StatePlay;

	// :: External Parameters parsed objects
	static var INI:ConfigFile;
	static var JSON:Dynamic;
	
	// :: DAMAGE VALUES 
	// I am using this simple naming style, first is who takes damage _ from whom
	// [INI FILE]
	public static var P_DAM = {
		from_hazard		: 30,	// [CPC] is 30
		fall_damage		: 150,
		from_ceil		: 1,	// [CPC] is 1
		i_time			: 0.6,	// Player invisibility times after being hit
		max_damage 		: 75,	// Max damage per hit, to enemy + player
	};

	// :: General Global Parameters 
	public static var P = {
		flicker_rate: 0.06,
		gravity : 410,
		confuse_time: 7	// Seconds
	};
	
	// ::
	public static var SND = {
		exit_unlock:"fx_2",	// long vibrato effect medium
		exit_travel:"fx_1",
		error:"error",
		weapon_get:"fx_3",
		
		item_bomb:"enemy_final",
		item_confuser:"enemy_final2",
		item_pickup:"item_pickup",
		item_equip:"fx_3",	// on inventory select
		item_use:"fx_5",
	};
	
	
	public static var SCORE = {
		enemy_hit:7,
		item_bomb:150,
		item_confuser:120,
		big_enemy_kill:90,
		enemy_kill:15,
	};

	// All states default BG color,
	static var BG_COLOR:Int = 0xFF000000;
	
	// This is the first level that a new game will start with
	public static var START_MAP = 'level_01';
	
	//====================================================;
	//====================================================;
	
	// >> Called BEFORE FlxGame() is created
	public static function init_pre()
	{
		trace(" == Reg init :PRE:");
		D.assets.DYN_FILES = [PATH_JSON, PATH_INI];
		D.assets.onAssetLoad = onAssetLoad;	
		D.snd.ROOT_SND = "snd/";
		D.snd.ROOT_MSC = "mus/";
		D.ui.initIcons([8]);
		
		// -- Game things: might be moved:
		IM = new ImageAssets();
	}//---------------------------------------------------;
	
	// >> Called AFTER FlxGame() is created
	public static function init_post()
	{
		trace(" == Reg init :POST:");
		D.snd.setVolume("master", 0.2);
		
		#if debug
			new Debug();
		#end
		
	}//---------------------------------------------------;
	
	// Whenever D.assets gets reloaded, I need to reparse the data into the objects
	// Then the state will be reset automatically
	static function onAssetLoad()
	{
		trace(" -- Reg Dynamic Asset Load");
		INI = new ConfigFile(D.assets.files.get(PATH_INI));
		JSON = Json.parse(D.assets.files.get(PATH_JSON));
			
		if (++_dtimes == 1)
		{
			D.snd.addMetadataNode(JSON.soundFiles);
		}
		
		
		START_MAP = INI.get('DEBUG', 'startLevel');
		
	}//---------------------------------------------------;
		static var _dtimes:Int = 0; // Asset loaded times

		
	// Quickly add the monitor border. And set it to be drawn at one camera only
	public static function add_border():FlxSprite
	{
		var st = FlxG.state;
		var a = new FlxSprite(0, 0, IM.STATIC.overlay_scr);
			a.scrollFactor.set(0, 0);
			a.active = false;
			a.camera = st.camera;
		st.add(a);
		return a;
	}//---------------------------------------------------;
	
	public static function openPauseMenu()
	{
		st.openSubState(new SubStatePause());
	}//---------------------------------------------------;
	
	
	public static function getSave():String
	{
		var s = "";
	
		Reg.st.player.health;
		Reg.st.player.lives;
		
		return s;
	}//---------------------------------------------------;
	
	
	// -- TODO :
	public static function checkProtection():Bool
	{
		return true;
		// !Reg.api.isURLAllowed()
	}//---------------------------------------------------;
	
	
	public static function SAVE_GET():Dynamic
	{
		var OBJ = {
			ver:VERSION,
			pl:st.player.SAVE(),
			inv:st.INV.SAVE(),
			hud:st.HUD.SAVE(),
			map:st.map.SAVE()
		};
		
		return OBJ;
		
	}//---------------------------------------------------;
	
}//--



