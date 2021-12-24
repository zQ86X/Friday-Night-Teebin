package;

import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;
import Song;

using StringTools;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
}

class StageData {
	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = (SONG.stage != null) ? SONG.stage : SONG.song != null ? switch (Paths.formatToSongPath(SONG.song))
		{
			case 'spookeez' | 'south' | 'monster': 'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice': 'philly';
			case 'milf' | 'satin-panties' | 'high': 'limo';
			case 'cocoa' | 'eggnog': 'mall';
			case 'winter-horrorland': 'mallEvil';
			case 'senpai' | 'roses': 'school';
			case 'thorns': 'schoolEvil';
			case 'magic-hands' | 'amen-breaks' | 'slapfight' | 'true-finale': 'teeb';
			default: 'stage';
		} : 'stage';

		var stageFile:StageFile = getStageFile(stage);
		if(stageFile == null) { //preventing crashes
			forceNextDirectory = '';
		} else {
			forceNextDirectory = stageFile.directory;
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/' + stage + '.json');

		if(Assets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		else
		{
			return null;
		}
		return cast Json.parse(rawJson);
	}
}