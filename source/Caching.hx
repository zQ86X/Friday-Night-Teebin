#if sys
package;

import lime.app.Application;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import flixel.ui.FlxBar;
import haxe.Exception;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
#if cpp
import sys.FileSystem;
import sys.io.File;
#end
import cpp.Function;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import meta.data.dependency.FNFUIState;
import meta.data.dependency.FNFSprite;
import meta.MusicBeat;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;

using StringTools;

class Caching extends FNFUIState
{
	public static var bitmapData:Map<String, FlxGraphic>;
	public static var loaded:Bool = false;

	var images:Array<String> = [];
	var music:Array<String> = [];

	var queues:Map<Array<String>, Dynamic>;

	var toBeDone:Int = 0;
	var done:Int = 0;

	var curItem:String;

	var time:FlxText;
	var text:FlxText;

	var sprite:FNFSprite;
	var speed:Float = Math.PI + (Math.PI / 2);
	// to prevent players from hanging on the load screen
	var timeout:Float = 30;

	var maxThreads:Int = 4;
	var threads:Int = 0;

	var dance:Float = 60 / 82;
	var bop:Float = 0;

	var cooldown:Float = 1 / 60;
	var debounce:Float = 0;
	// wait for some time before preloading the queue
	var delay:Float = 1;
	var delta:Float = 0;

	private function recenterText()
	{
		text.screenCenter();
		time.screenCenter();

		text.y += sprite.height / (Math.PI / 2);
		time.y = text.y + (text.size + (time.size / 2));
	}
	override function create()
	{
		FlxG.mouse.visible = false;
		FlxG.worldBounds.set(0, 0);
		/*
		[0] - paths (string or array)
		[1] - filetypes (string or array)
		*/
		var scans:Map<Array<String>, Array<Dynamic>> = [
			music => [["assets/songs", "assets/music", "assets/sounds"], ["ogg", "mp3"]],
			images => ["assets/images", "png"]
		];

		bitmapData = new Map<String, FlxGraphic>();
		// get the first image in the image queue then cache it, same with songs
		queues = [
			images => function(image:String)
			{
				var replaced:String = image.replace(".png", "");
				var path:String = Paths.image('characters/$replaced');//'assets/images/characters/$image';

				var data:BitmapData = BitmapData.fromFile(path);
				var graphic = FlxGraphic.fromBitmapData(data);

				graphic.persist = true;
				bitmapData.set(replaced, graphic);
			},
			music => function(track:String)
			{
				FlxG.sound.cache(Paths.inst(track));
				FlxG.sound.cache(Paths.voices(track));
			}
		];

		if (time != null) time.destroy();
		if (text != null) text.destroy();

		curItem = null;
		threads = 0;

		debounce = 0;
		delta = 0;

		time = new FlxText();
		text = new FlxText();

		text.alignment = FlxTextAlign.CENTER;
		text.size = 32;

		time.size = Std.int(text.size / (Math.PI / 2));
		time.alignment = FlxTextAlign.LEFT;

		sprite = new FNFSprite(FlxG.width / 2, FlxG.height / 2);
		sprite.frames = Paths.getSparrowAtlas('characters/Teebicus_Assets');

		sprite.setGraphicSize(Std.int(sprite.width * .6));

		sprite.screenCenter();
		sprite.updateHitbox();

		sprite.animation.addByPrefix('idle', 'TEEB_IDLE', Std.int(24 * (dance * 2)), false);
		sprite.animation.addByPrefix('finish', 'TEEB_POSE', 24, false);

		sprite.playAnim('idle', true);
		recenterText();

		FlxGraphic.defaultPersist = true;
		trace("pushing items in arrays to queue");
		#if cpp
		for (array in scans.keys())
		{
			var data:Array<Dynamic> = scans.get(array);

			var directories = data[0];
			var fileTypes = data[1];

			if (Std.isOfType(directories, String)) recurseDirectory(array, directories, fileTypes);
			else
			{
				var recursive:Array<String> = directories;
				for (directory in recursive) recurseDirectory(array, directory, fileTypes);
			}
			var count:Int = Lambda.count(array);

			toBeDone += count;
			trace('pushed $count items to the array');
		}
		#else
		loaded = true;
		Main.switchState(this, new Init());
		#end

		FlxG.sound.playMusic(Paths.music("loading"), .5);
		add(sprite);

		add(time);
		add(text);

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (!loaded && toBeDone > 0)
		{
			delta += elapsed;
			if (delta >= delay && delta >= debounce && threads < maxThreads)
			{
				debounce = delta + cooldown;
				// get each queue and call their functions
				for (queue in queues.keys())
				{
					// make sure the thread limit isn't exceeded
					if (threads >= maxThreads) break;

					var job = queues.get(queue);
					if (queue.length > 0)
					{
						var item:String = queue[0];

						queue.remove(item);
						curItem = item;

						trace('caching item $item (threads going to reach ${threads + 1}, limit is $maxThreads)');
						#if cpp
						sys.thread.Thread.create(() -> { threads++; job(item); done++; threads--; });
						#else
						job(item);
						done++;
						#end
					}
				}
			}
			if (done >= toBeDone || elapsed >= timeout)
			{
				loaded = true;
				FlxG.sound.music.fadeOut(Math.PI / 2, 0, function(twn:FlxTween)
				{
					FlxG.sound.music.stop();
					Main.switchState(this, new Init());

					twn.destroy();
				});
				FlxG.sound.play(Paths.sound("confirmMenu"));

				time.visible = false;
				text.text = "Loaded!";

				text.alpha = 1;
				text.angle = 0;

				sprite.playAnim('finish', true);
				recenterText();

				trace("caching finished");
			}
			else
			{
				bop += elapsed;
				if (bop >= dance)
				{
					bop %= dance;
					sprite.playAnim('idle', true);
				}
				if (text != null && time != null)
				{
					var sine:Float = Math.sin(((delta * speed) + Math.PI) % (Math.PI * 2));
					var difference:Int = Math.floor(timeout - delta);

					var fmt = curItem != null ? '\n$curItem' : "";

					time.text = '${difference} second${difference == 1 ? "" : "s"} until skip$fmt';
					text.text = '$done/$toBeDone Loaded';

					text.alpha = Math.abs(sine);
					text.angle = sine * Math.PI;

					recenterText();
				}
			}
		}
		super.update(elapsed);
	}

	private function recurseDirectory(array:Array<String>, directory:Any, ?fileTypes:Any)
	{
		//for (file in FileSystem.readDirectory(FileSystem.absolutePath("assets/images/characters"))) { if (file.endsWith(".png")) images.push(file); }
		//for (file in FileSystem.readDirectory(FileSystem.absolutePath("assets/images/icons"))) { if (file.endsWith(".png")) images.push(file); }

		//for (track in FileSystem.readDirectory(FileSystem.absolutePath("assets/sounds"))) music.push(track);
		//for (track in FileSystem.readDirectory(FileSystem.absolutePath("assets/music"))) music.push(track);
		//for (track in FileSystem.readDirectory(FileSystem.absolutePath("assets/songs"))) music.push(track);
		for (item in FileSystem.readDirectory(FileSystem.absolutePath(directory)))
		{
			var path:String = '$directory/$item';
			if (FileSystem.isDirectory(path)) recurseDirectory(array, path, fileTypes);
			else
			{
				if (fileTypes != null)
				{
					if (Std.isOfType(fileTypes, String)) { if (!item.endsWith(fileTypes)) continue; }
					else
					{
						var fileTypeArray:Array<String> = fileTypes;
						var pass:Bool = true;

						for (fileType in fileTypeArray) { if (item.endsWith(fileType)) { pass = false; break; } }
						if (pass) continue;
					}
				}
				array.push(item);
			}
		}
	}
	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}
}
#end