package;

import sys.thread.Thread;
import lime.app.Application;

import sys.FileSystem;
import sys.io.File;

import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import meta.data.dependency.FNFUIState;
import meta.data.dependency.FNFSprite;
import flixel.text.FlxText;

using StringTools;

class Caching extends FNFUIState
{
	public static var bitmapData:Map<String, FlxGraphic>;
	public static var loaded:Bool = false;

	private var pathStart:String = 'assets';

	var images:Array<Array<String>> = [];
	var music:Array<Array<String>> = [];

	var queues:Map<Array<Array<String>>, Dynamic>;

	var toBeDone:Int = 0;
	var done:Int = 0;

	var curItem:String;

	var time:FlxText;
	var text:FlxText;

	var sprite:FNFSprite;
	var speed:Float = Math.PI + (Math.PI / 2);
	// to prevent players from hanging on the load screen
	var timeout:Float = 30;

	var maxThreads:Int = 2;
	var threads:Int = 0;

	var dance:Float = 60 / 82;
	var bop:Float = 0;
	// wait for some time before preloading the queue
	var totalElapsed:Float = 0;
	var delay:Float = 1;

	private function cacheSound(path:String) { if (OpenFlAssets.exists(path)) FlxG.sound.cache(path); }
	private function recenterText()
	{
		text.screenCenter();
		time.screenCenter();

		text.y += sprite.height / (Math.PI / 2);
		time.y = text.y + (text.size + (time.size / 2));
	}
	override function create()
	{
		loaded = true;

		FlxG.mouse.visible = false;
		FlxG.worldBounds.set(0, 0);

		if (time != null) time.destroy();
		if (text != null) text.destroy();

		FlxGraphic.defaultPersist = true;
		#if !html5
		loaded = false;
		/*
		[0] - paths (string or array)
		[1] - filetypes (string or array)
		[2] - check (function)
		*/
		var scans:Map<Array<Array<String>>, Array<Dynamic>> = [
			music => [['$pathStart/songs', '$pathStart/music', '$pathStart/sounds'], ["ogg", "mp3"]],
			images => ['$pathStart/images', "png", function(path:String):Bool {
				#if linux
				return false;
				#end
				trace(path);
				return OpenFlAssets.exists('$path.xml') || OpenFlAssets.exists('$path.txt');
			}]
		];
		bitmapData = new Map<String, FlxGraphic>();
		// get the first image in the image queue then cache it, same with songs
		queues = [
			images => function(data:Array<String>)
			{
				var path:String = data[1];
				// gets rid of the filetype (always png) and shortens the directory
				var replaced:String = path.substring(data[3].length + 1, path.length - 4);

				var data:BitmapData = OpenFlAssets.getBitmapData(path);
				var graphic:FlxGraphic = FlxGraphic.fromBitmapData(data);

				graphic.persist = true;
				graphic.destroyOnNoUse = false;

				bitmapData.set(replaced, graphic);
				trace('added $replaced bitmap data');
			},
			music => function(data:Array<String>)
			{
				var track:String = data[0];

				cacheSound(Paths.voices(track));
				cacheSound(Paths.inst(track));
			}
		];

		curItem = null;

		totalElapsed = 0;
		threads = 0;

		time = new FlxText();
		text = new FlxText();

		text.alignment = FlxTextAlign.CENTER;

		text.text = "?/? Loaded";
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

		trace("pushing items in arrays to queue");
		for (array in scans.keys())
		{
			var data:Array<Dynamic> = scans.get(array);

			var directories = data[0];
			var fileTypes = data[1];
			var check = data[2];

			if (Std.isOfType(directories, String)) recurseDirectory(array, directories, fileTypes, check, directories);
			else
			{
				var recursive:Array<String> = directories;
				for (directory in recursive) recurseDirectory(array, directory, fileTypes, check, directory);
			}

			var count:Int = Lambda.count(array);
			toBeDone += count;

			trace('pushed $count items to the array from $directories');
		}

		FlxG.sound.playMusic(Paths.music("loading"), .5);
		add(sprite);

		add(time);
		add(text);
		#else
		Main.switchState(this, new Init());
		#end
		super.create();
	}
	#if !html5
	override function update(elapsed:Float)
	{
		if (!loaded && toBeDone > 0)
		{
			totalElapsed += elapsed;
			if (totalElapsed >= delay)
			{
				while (threads < maxThreads && done < toBeDone)
				{
					// get each queue and call their functions
					for (queue in queues.keys())
					{
						var job = queues.get(queue);
						if (queue.length > 0)
						{
							var item:Array<String> = queue[0];
							if (item != null)
							{
								queue.remove(item);
								curItem = item[1];

								trace('caching item $item (thread #${threads + 1})');
								// if it can thread then i will do
								#if cpp
								Thread.create(() -> { threads++; job(item); queue.remove(item); done++; threads--; });
								#else
								job(item);
								done++;
								#end
							}
						}
						// break if max threads reached or all done
						if (threads >= maxThreads || done >= toBeDone) break;
					}
				}
			}

			var skipPressed:Bool = FlxG.keys.justPressed.ESCAPE;
			if (done >= toBeDone || totalElapsed >= timeout || skipPressed)
			{
				loaded = true;
				if (skipPressed)
				{
					if (bitmapData != null) bitmapData.clear();
					text.text = "Skipped!";
				}
				else text.text = '$done/$toBeDone Loaded!';
				FlxG.sound.music.fadeOut(Math.PI / 2, 0, function(twn:FlxTween)
				{
					if (skipPressed) bitmapData = null;

					FlxG.sound.music.stop();
					Main.switchState(this, new Init());

					twn.destroy();
				});

				FlxG.sound.play(Paths.sound("confirmMenu"));
				time.visible = false;

				text.alpha = 1;
				text.angle = 0;

				sprite.playAnim('finish', true);
				recenterText();

				trace("caching finished");
				trace(OpenFlAssets.cache.hasBitmapData('GF_assets'));
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
					var sine:Float = Math.sin(((totalElapsed * speed) + Math.PI) % (Math.PI * 2));
					var difference:Int = Math.floor(timeout - totalElapsed);

					var fmt = curItem != null ? '\n$curItem' : "";

					time.text = 'Press Escape or wait ${difference} second${difference == 1 ? "" : "s"} to skip loading$fmt';
					text.text = '$done/$toBeDone Loaded';

					text.alpha = Math.abs(sine);
					text.angle = sine * Math.PI;

					recenterText();
				}
			}
		}
		super.update(elapsed);
	}

	private function recurseDirectory(array:Array<Array<String>>, directory:Any, ?fileTypes:Any, ?check:Dynamic, start:String)
	{
		for (item in FileSystem.readDirectory(FileSystem.absolutePath(directory)))
		{
			var path:String = '$directory/$item';
			if (FileSystem.isDirectory(path)) recurseDirectory(array, path, fileTypes, check, start);
			else
			{
				var cut:String = path;
				if (fileTypes != null)
				{
					if (Std.isOfType(fileTypes, String)) { if (!item.endsWith(fileTypes)) continue; cut = path.substring(0, path.length - '.$fileTypes'.length); }
					else
					{
						var fileTypeArray:Array<String> = fileTypes;
						var pass:Bool = true;

						for (fileType in fileTypeArray) { if (item.endsWith(fileType)) { cut = path.substring(0, path.length - '.$fileType'.length); pass = false; break; } }
						if (pass) continue;
					}
				}
				if (check != null && !check(cut)) continue;
				array.push([item, path, directory, start]);
			}
		}
	}
	#end
	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}
}