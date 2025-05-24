package funkin.data;

#if USING_MOONCHART
import funkin.data.Song;
import funkin.data.BaseSong;

import moonchart.formats.fnf.legacy.FNFTroll as SupportedFormat;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyBasic;
import moonchart.formats.StepMania.StepManiaBasic;
import moonchart.formats.StepMania;
import moonchart.formats.BasicFormat;
import moonchart.backend.FormatDetector;
import moonchart.backend.FormatData;
import moonchart.backend.Util as MoonchartUtil;
import moonchart.Moonchart;

using StringTools;
using funkin.CoolerStringTools;

typedef StepManiaDynamic = moonchart.formats.StepMania.StepManiaBasic<moonchart.parsers.StepManiaParser.StepManiaFormat>;

final SM_DIFFICULTIES = ["Beginner", "Easy", "Medium", "Hard", "Challenge"]; // idk I don't play Stepmania
final FNF_DIFFICULTIES = ["easy", "normal", "hard", "erect", "nightmare"];

class MoonchartSong extends BaseSong
{
	final ss:SowySongData;
	final diffList:Array<String>;
	final diffMap:Map<String, SowyDiffData>;
	final meta:SongMetadata;

	public function new(ss:SowySongData) {
		this.ss = ss;
		this.diffList = [];
		this.diffMap = [];

		for (diff in ss.diffData) {
			diffList.push(diff.ID);
			diffMap.set(diff.ID, diff);
		}

		var displayName = ss.ID.replace("-", " ").capitalize();
		this.meta = {songName: displayName, freeplayIcon: 'moonchart'};

		super(ss.ID, "moonchart");
	}

	/**
	 * Returns metadata for the requested chartId. 
	 * If it doesn't exist, metadata for the default chart is returned instead
	 * 
	 * @param chartId The song chart for which you want to request metadata
	**/
	public function getMetadata(chartId:String = DEFAULT_CHART_ID):SongMetadata
	{
		return meta;
	}

	/**
	 * Returns an array of charts available for this song
	**/
	public function getCharts():Array<String>
	{
		return diffList;
	}

	/**
	 * Returns chart data for the requested chartId. 
	 * If it doesn't exist, null is returned instead
	 * 
	 * @param chartId The song chart for which you want to request chart data
	**/
	public function getSwagSong(chartId:String = DEFAULT_CHART_ID):Null<SwagSong>
	{
		if (!diffMap.exists(chartId)) 
			return null;
		
		var diffData:SowyDiffData = diffMap.get(chartId);

		if (ss.sowyFormat.basicFormat is FNFLegacyBasic) {
			// Skip Moonchart Conversion
			@:privateAccess
			return Song.parseSongJson(diffData.chartPath);
		}

		if (ss.sowyFormat.basicFormat is StepManiaBasic) 
		@:privateAccess
		{
			var basicFormat:StepManiaDynamic = cast ss.sowyFormat.basicFormat;
			basicFormat.data = cast basicFormat.parser.parse(Paths.getContent(diffData.chartPath));
			basicFormat.diffs = [chartId] ?? MoonchartUtil.mapKeyArray(basicFormat.data.NOTES);

			var convertedData:JsonSong = cast new SupportedFormat().fromFormat(basicFormat, diffData.ID).data.song;
			convertedData._path = diffData.chartPath;
			convertedData.tracks = {inst: [FileNameUtil.withoutExtension(basicFormat.data.MUSIC)]};
			convertedData.metadata ??= {};
			convertedData.metadata.songName = basicFormat.data.TITLE;
			
			@:privateAccess
			return Song.onLoadJson(convertedData);
		}

		var parsedData = ss.sowyFormat.basicFormat.fromFile(diffData.chartPath, diffData.metaPath, diffData.ID);
		var convertedData:JsonSong = cast new SupportedFormat().fromFormat(parsedData, diffData.ID).data.song;
		convertedData._path = diffData.chartPath;
		convertedData.tracks = null;

		@:privateAccess
		return Song.onLoadJson(convertedData);
	}

	/**
	 * Returns a path to a file of name fileName that belongs to this song
	**/
	public function getSongFile(fileName:String):String
	{
		return MoonchartUtil.extendPath(ss.folderPath, fileName);
	}
}

// mod folders should be a class methinks
class MoonchartContent
{
	public static var freeplaySongs:Array<BaseSong> = [];
	
	private static var initialized = false;
	private static var formatMap = new Map<Format, SowyFormatData>();

	public static function init() {
		if (initialized) return;

		////
		Moonchart.DEFAULT_DIFF = DEFAULT_CHART_ID;
		Moonchart.init();

		for (formatData in FormatDetector.formatMap) {
			// not dealing with ts
			if (formatData.hasMetaFile == TRUE)
				continue;

			var formatId = formatData.ID;
			var folderPath:String = MoonchartUtil.extendPath('content/moonchart/moonchart', formatId);
			var sowyData = new SowyFormatData(formatId, folderPath);
			formatMap.set(formatId, sowyData);

			if (formatData.ID.startsWith("FNF"))
				sowyData.diffSortFunc = SortUtil.stringSort.bind(FNF_DIFFICULTIES);
			
			#if sys
			sys.FileSystem.createDirectory(sowyData.folderPath);
			#end
		}
		formatMap.get(STEPMANIA).diffSortFunc = SortUtil.stringSort.bind(SM_DIFFICULTIES);

		////
		initialized = true;
	}

	public static function scanSongs() {
		//songs.clear();
		freeplaySongs.resize(0);

		for (sowyFormat in formatMap) {
			sowyFormat.scanSongs();
			var formatSongs:Array<MoonchartSong> = [];
			for (sowySong in sowyFormat.songs) {
				var song = new MoonchartSong(sowySong);
				//songs.set(song.songId, song);
				formatSongs.push(song);
			}
			formatSongs.sort((a, b) -> SortUtil.alphabeticalSort(a.songId, b.songId));
			for (song in formatSongs) freeplaySongs.push(song);
		}
	}
}

// moonchart format classes need a fromFolder function grrrr

////
class SowyFormatData
{
	public final ID:Format;
	public final formatData:FormatData;
	public final basicFormat:DynamicFormat;
	public final folderPath:String;

	/** Function to sort the song's difficulties **/
	public var diffSortFunc:(String, String) -> Int = SortUtil.alphabeticalSort;

	public final songs = new Array<SowySongData>();

	public function new(ID:Format, folderPath:String) {
		this.ID = ID;
		this.formatData = FormatDetector.getFormatData(ID);
		this.basicFormat = FormatDetector.createFormatInstance(ID);
		this.folderPath = folderPath;
	}

	public function scanSongs() {
		songs.resize(0);

		for (songId in MoonchartUtil.readFolder(folderPath)) {
			var songFolderPath:String = MoonchartUtil.extendPath(folderPath, songId);

			var diffs = DiffFinder.fromFolder(this, songId, songFolderPath);
			var diffs = [for (v in diffs) v];
			diffs.sort((a,b) -> diffSortFunc(a.ID, b.ID));
			
			var song = new SowySongData(this, songId, songFolderPath, diffs);
			songs.push(song);
		}

		return songs;
	}
}

/** difficultyId => filePath **/ 
typedef DiffMap = Map<String, SowyDiffData>;

class DiffFinder
{
	public static function fromFolder(sowyFormat:SowyFormatData, songId:String, songFolderPath:String):DiffMap
	{
		var formatData:FormatData = sowyFormat.formatData;
		var folderFiles:Array<String> = MoonchartUtil.readFolder(songFolderPath).filter(FileNameUtil.hasExtension.bind(formatData.extension));

		if (sowyFormat.basicFormat.formatMeta.supportsDiffs) // why is this data stored on the instances 
			return fromFileDiffs(sowyFormat.basicFormat, songFolderPath, folderFiles);
		else
			return fromFileSuffix(songFolderPath, folderFiles, songId);
	}

	/** Get difficulties from the first file with one or more valid difficulty **/
	static function fromFileDiffs(basicFormat:DynamicFormat, folderPath:String, folderFiles:Array<String>, ?diffsMap:DiffMap):DiffMap 
	{
		diffsMap ??= new Map();
		for (fileName in folderFiles) {
			var filePath:String = MoonchartUtil.extendPath(folderPath, fileName);
			var chart:DynamicFormat;
			
			try {
				chart = basicFormat.fromFile(filePath);
			}
			catch(e) {
				chart = null;
				trace(e);
			}

			if (chart != null && chart.diffs.length > 0) {
				for (diff in chart.diffs)
					diffsMap.set(diff, new SowyDiffData(diff, filePath));
				//break; 
			}
		}
		return diffsMap;
	}

	/** Get difficulties by file names ('$songId-$difficultyId') **/
	static function fromFileSuffix(folderPath:String, folderFiles:Array<String>, songId:String, ?diffsMap:DiffMap):DiffMap
	{
		diffsMap ??= new Map();

		for (fileName in folderFiles) {				
			inline function getFilePath()
				return MoonchartUtil.extendPath(folderPath, fileName);
		
			var woExtension:String = FileNameUtil.withoutExtension(fileName);
			if (woExtension == songId){
				var diff:String = DEFAULT_CHART_ID;
				diffsMap.set(diff, new SowyDiffData(diff, getFilePath()));
				continue;
			}

			var prefix:String = '$songId-';
			if (woExtension.startsWith(prefix)){
				var diff:String = woExtension.substring(prefix.length, woExtension.length);
				diffsMap.set(diff, new SowyDiffData(diff, getFilePath()));
				continue;
			}
		}

		return diffsMap;
	}
}

class SowySongData
{
	public final ID:String;
	public final folderPath:String;
	public final diffData:Array<SowyDiffData>;
	public final sowyFormat:SowyFormatData;
	
	public function new(sowyFormat:SowyFormatData, ID:String, folderPath:String, diffData:Array<SowyDiffData>) {
		this.sowyFormat = sowyFormat;
		this.ID = ID;
		this.folderPath = folderPath;
		this.diffData = diffData;
	}
}

class SowyDiffData
{
	public final ID:String;
	public final chartPath:String;
	public final metaPath:Null<String> = null;

	public function new(ID:String, chartPath:String, ?metaPath:String) {
		this.ID = ID;
		this.chartPath = chartPath;
		this.metaPath = metaPath;
	}

	public function toString()
		return ID;
}
#end

////
// probably faster than Path because it doesn't account for full path (???)
class FileNameUtil {
	public static function withoutExtension(file:String):String {
		var dotPos:Int = file.lastIndexOf(".");
		return (dotPos < 0) ? file : file.substring(0, dotPos);
	}

	public static function getExtension(file:String):String {
		var dotPos:Int = file.lastIndexOf(".");
		return (dotPos < 0) ? file : file.substring(dotPos + 1, file.length);
	}

	public static function hasExtension(extension:String, fileName:String):Bool {
		var fileExtension = FileNameUtil.getExtension(fileName);
		return fileExtension == extension;
	}
}

class SortUtil {
	public static function alphabeticalSort(a:String, b:String):Int {
		// https://haxe.motion-twin.narkive.com/BxeZgKeh/sort-an-array-string-alphabetically
		a = a.toLowerCase();
		b = b.toLowerCase();
		if (a < b) return -1;
		if (a > b) return 1;
		return 0;	
	}

	public static function stringSort(ordering:Array<String>, a:String, b:String) {
		// stolen from v-slice lol!
		if(a==b) return 0;

		var aHasDefault = ordering.contains(a);
		var bHasDefault = ordering.contains(b);
		if (aHasDefault && bHasDefault)
			return ordering.indexOf(a) - ordering.indexOf(b);
		else if(aHasDefault)
			return 1;
		else if(bHasDefault)
			return -1;

		return a > b ? -1 : 1;
	}
}