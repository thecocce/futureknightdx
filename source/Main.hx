package;

import djFlixel.D;
import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite
{
	inline static var FPS = 40;
	inline static var START_STATE = StatePlay;
	
	public function new() 
	{
		super();
		
		// :: First thing initialize djFlixel
		D.init({
			name:"Future Knight Remake v1.4",
			debug_keys:true	// Automatic asset reload on F12
		});
		
		// :: Do this before creating the game
		Reg.init();
		
		// :: Start the game after loading the dynamic assets (they were defined in Reg.init)
		D.assets.reload( ()->{	
			addChild(new FlxGame(320, 240, START_STATE, 2, FPS, FPS, true));
		});
		
	}//---------------------------------------------------;
	
}//--end class--