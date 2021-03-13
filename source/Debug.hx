/**
   Quick and dirty add some debugging functions to the game
  
   - Press [`] to open up the debugger
   - In the console you can access this object with [D]
   
------------------------------------------*/


package;
import djFlixel.D;
import flixel.FlxG;
import gamesprites.Item.ITEM_TYPE;
import states.StatePlay;

class Debug 
{

	public function new() 
	{
		FlxG.console.registerObject("D", this);
		
		if (Reg.INI.exists('DEBUG', 'startPlay'))
			FlxG.switchState(new StatePlay());
			
		if (Reg.INI.exists('DEBUG', 'delsave')){
			D.save.deleteSave();
			trace("INI File Trigger > Save Deleted");
		}
	}//---------------------------------------------------;

	public function pl_kill()
	{
		Reg.st.player.health = 0;
		@:privateAccess Reg.st.player.healthSlow = 2;
		FlxG.log.notice('Player Heath = 0');
	}//---------------------------------------------------;
	
	public function pl_fulldamage()
	{
		Reg.st.player.hurt(999);
		FlxG.log.notice('Player Hurt 999');
	}//---------------------------------------------------;
	
	@:access(gamesprites.Player)
	public function pl_weapon(a:Int)
	{
		Reg.st.player.bullet_type = a;
		Reg.st.HUD.bullet_pickup(a);
	}//---------------------------------------------------;
	
	public function item_add(i:Int)
	{
		var item = ITEM_TYPE.createByIndex(i);
		trace("Adding item ",item);
		Reg.st.INV.addItem(item);
	}//---------------------------------------------------;
	
	public function load(lData:String)
	{
		Reg.st.map.loadMap(lData);
	}//---------------------------------------------------;
	
	public function flash()
	{
		Reg.st.map.flash(20);
	}//---------------------------------------------------;
	
	public function save()
	{
		Reg.SAVE_GAME();
	}//---------------------------------------------------;
	
	public function saveDel()
	{
		D.save.deleteSave();
	}
	
	public function map_append()
	{
		Reg.st.map.appendMap();
	}
	public function map_append_remove()
	{
		Reg.st.map.appendRemove();
	}
	
	public function showKilled()
	{
		trace("List globally killed entities");
		var kg = @:privateAccess Reg.st.map._killed_global;
		trace(kg);
	}//---------------------------------------------------;
	
}// --