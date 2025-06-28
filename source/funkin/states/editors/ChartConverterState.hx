package funkin.states.editors;

#if USING_MOONCHART
import lime.ui.FileDialog;
import lime.utils.Resource;
import lime.system.System;
import sys.FileSystem;
import haxe.io.Path;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.addons.ui.FlxUIText;
import flixel.addons.ui.FlxUITypedButton;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIDropDownMenu;

import moonchart.backend.Util as MoonchartUtil;
import moonchart.backend.FormatData;
import moonchart.backend.FormatDetector;
import moonchart.formats.BasicFormat;
import moonchart.formats.BasicFormat.DynamicFormat;

class ChartConverterState extends MusicBeatState
{
	var formatList:Array<Format>;
	
	var fromFormat:Format;
	var goalFormat:Format;
	
	var fromSupportsDiffs:Bool;
	var goalSupportsDiffs:Bool;
	var metaPath:String;
	var chartPaths:Array<String>;

	var chartDialog:FileDialog;
	var metaDialog:FileDialog;

	////
	var infoText:FlxText;

	override function create() {
		super.create();

		FlxG.mouse.visible = true;

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.color = FlxColor.fromHSB(Std.random(64) * 5.625, 0.15, 0.15);
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		chartDialog = new FileDialog();
		chartDialog.onSelectMultiple.add(onSelectChartFiles);

		metaDialog = new FileDialog();
		metaDialog.onSelectMultiple.add(onSelectMetaFiles);

		var x = FlxG.width / 3 - 200;
		var y = FlxG.height / 2;
		
		var x2 = x + x;
		
		formatList = FormatDetector.getList();
		var formatList2 = FlxUIDropDownMenu.makeStrIdLabelArray(formatList, true);

		var fromFormatDD = new FlxUIDropDownMenu(x, y, formatList2);
		fromFormatDD.name = "fromFormatDD";
		fromFormatDD.header.text.text = "SELECT FORMAT";

		var selectMetaButt = new FlxUIButton(fromFormatDD.x + fromFormatDD.width + 15, fromFormatDD.y, "Browse Metadata");
		selectMetaButt.name = "selectMetaButt";

		var selectChartsButt = new FlxUIButton(selectMetaButt.x, selectMetaButt.y + 40, "Browse Charts");
		selectChartsButt.name = "selectChartsButt";

		////
		var goalFormatDD = new FlxUIDropDownMenu(x2, y, formatList2);
		goalFormatDD.name = "goalFormatDD";
		goalFormatDD.header.text.text = "SELECT FORMAT";

		var convertFilesButt = new FlxUIButton(goalFormatDD.x + goalFormatDD.width + 15, goalFormatDD.y, "Convert");
		convertFilesButt.name = "convertFilesButt";

		////
		infoText = new FlxText(15, 15);
		this.add(infoText);
		updateInfoText();

		var moonchartVer = new FlxText(5,5,0,MoonchartUtil.version);
		moonchartVer.y = FlxG.height - moonchartVer.height - moonchartVer.y;
		this.add(moonchartVer); 

		////
		this.add(new FlxText(fromFormatDD.x, fromFormatDD.y - 15, 0, 'Input Format'));
		this.add(fromFormatDD);

		this.add(selectMetaButt);
		
		this.add(selectChartsButt);

		////
		this.add(new FlxText(goalFormatDD.x, goalFormatDD.y - 15, 0, 'Output Format'));
		this.add(goalFormatDD);

		this.add(convertFilesButt);
	}

	function updateInfoText() {
		var str = "\n";
		str += 'Metadata:\n$metaPath\n';
		str += 'Chart:\n${chartPaths?.join('\n')}\n';
		infoText.text = str;
	}

	static function getCommonStringsStart(strings:Array<String>):String {
		var commonCharacters:Int = 0;
		var longest:String = "";

		for (str in strings) {
			var l = str.length;
			if (l > commonCharacters) {
				commonCharacters = l;
				longest = str;
			}
		}

		for (str1 in strings) {
			for (str2 in strings) {
				var commonCharacters2:Int = 0;

				for (i in 0...str1.length) {
					if (str1.charCodeAt(i) == str2.charCodeAt(i))
						commonCharacters2++;
					else
						break;
				}

				if (commonCharacters2 < commonCharacters)
					commonCharacters = commonCharacters2;
			}
		}

		return longest.substr(0, commonCharacters);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		//trace(id,data);

		switch(id) {
			case FlxUITypedButton.CLICK_EVENT:
				switch(sender.name) {
					case 'selectMetaButt':
						metaDialog.browse(OPEN_MULTIPLE);
					case 'selectChartsButt':
						chartDialog.browse(OPEN_MULTIPLE);
					case 'convertFilesButt':
						convert();
				}

			case FlxUIInputText.CHANGE_EVENT:
				//

			case FlxUIDropDownMenu.CLICK_EVENT:
				var sender:FlxUIDropDownMenu = cast sender;

				switch(sender.name) {
					case 'fromFormatDD':
						fromFormat = formatList[Std.parseInt(data)];

						// WHY IS THIS HERE
						var handler = FormatDetector.createFormatInstance(fromFormat);
						fromSupportsDiffs = handler.formatMeta.supportsDiffs;
					
					case 'goalFormatDD':
						goalFormat = formatList[Std.parseInt(data)];

						// WHY IS THIS HERE
						var handler = FormatDetector.createFormatInstance(goalFormat);
						goalSupportsDiffs = handler.formatMeta.supportsDiffs;
			}			
		}
	}

	function onSelectMetaFiles(paths:Array<String>) {
		metaPath = paths[0];
		updateInfoText();
	}

	function onSelectChartFiles(paths:Array<String>)
	{
		chartPaths = paths;
		updateInfoText();
	}

	function convert() {
		if (fromFormat == null) {
			openSubState(new Prompt('Please select input format'));
			return;
		}
		if (goalFormat == null) {
			openSubState(new Prompt('Please select output format'));
			return;
		}

		if (chartPaths == null) {
			openSubState(new Prompt('Please select song chart files'));
			return;
		}

		var fromFormatData = FormatDetector.getFormatData(fromFormat);
		var goalFormatData = FormatDetector.getFormatData(goalFormat);

		if (fromFormatData.hasMetaFile == TRUE && metaPath == null) {
			openSubState(new Prompt('Input format requires a metadata file'));
			return;
		}

		var fromHandlers:Array<DynamicFormat> = [];

		var prevCwd = Sys.getCwd();
		Sys.setCwd('');

		if (fromSupportsDiffs) {
			
			for (path in chartPaths) {
				trace(path);

				var handler = FormatDetector.createFormatInstance(fromFormat);
				handler = handler.fromFile(path, metaPath);
				if (handler != null)
					fromHandlers.push(handler);
			}
		}else {
			trace(chartPaths);
			
			/*
				expecting "$songName-$diffName" named files, just "$diffName" should work too
			*/

			//chartPaths.sort((a:String,b:String) -> a.length-b.length);

			var fileNames:Array<String> = [for (path in chartPaths) new Path(path).file];
			var songName:String = getCommonStringsStart(fileNames);
			
			for (i in 0...chartPaths.length) 
			{
				var fileName:String = fileNames[i];
				var diffName:String = (songName.length==fileName.length) ? 'normal' : fileName.substring(songName.length + 1);

				trace(songName, diffName);
				
				var handler = FormatDetector.createFormatInstance(fromFormat);
				handler = handler.fromFile(chartPaths[i], metaPath, diffName);
				if (handler != null)
					fromHandlers.push(handler);
			}
		}

		Sys.setCwd(prevCwd);

		///
		FileSystem.createDirectory('moonchartConverted');

		if (goalSupportsDiffs) {
			var goalHandler = FormatDetector.createFormatInstance(goalFormat);
			goalHandler = goalHandler.fromFormat(fromHandlers);
			goalHandler.save('moonchartConverted/chart.json', 'moonchartConverted/meta.json');
		}else {
			var exportMeta = goalFormatData.hasMetaFile != FALSE;
			
			for (fromHandler in fromHandlers) {
				var diff:String = fromHandler.diffs[0];
				var chartPath:String = 'moonchartConverted/chart-$diff.json';
				var metaPath:Null<String> = exportMeta ? 'moonchartConverted/meta-$diff.json' : null;
				
				var goalHandler = FormatDetector.createFormatInstance(goalFormat);
				goalHandler = goalHandler.fromFormat(fromHandler);
				goalHandler.save(chartPath, metaPath);
			}
		}
		openSubState(new Prompt('Save success'));
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) {
			MusicBeatState.switchState(new MasterEditorMenu());
		}
	} 
}
#end