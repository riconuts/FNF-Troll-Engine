package sowy;

// what DOES sowy mean
using StringTools;

typedef RepoInfo = {
    var user:String;
    var repo:String;
}
class Sowy
{
    public inline static var YELLOW = 0xFFF4CC34;

    public static macro function getBuildDate()
    {
        var daDate = Date.now();
        
        var monthsPassed = Std.string((daDate.getUTCFullYear() - 2023) * 12 + (daDate.getUTCMonth() + 1));
        if (monthsPassed.length == 1)
            monthsPassed = "0"+monthsPassed;

        var theDays = Std.string(daDate.getDate());
        if (theDays.length == 1)
            theDays = "0"+theDays;

        var daString = '$monthsPassed-$theDays';

        return macro $v{daString};
    }

	// based on https://code.haxe.org/category/macros/add-git-commit-hash-in-build.html
    // pretty much gets the github repo lol
    public static macro function getRepoInfo(){
		#if !display
		var process = new sys.io.Process('git', ['config', '--get', 'remote.origin.url']);
		if (process.exitCode() != 0)
		{
			var message = process.stderr.readAll().toString();
			var pos = haxe.macro.Context.currentPos();
			haxe.macro.Context.warning("Cannot execute 'git config --get remote.origin.url' " + message, pos);
			var repoInfo:RepoInfo = {
				user: "riconuts",
				repo: "troll-engine"
			}
			return macro $v{repoInfo};
		}

		// read the output of the process
		var originUrl:String = process.stdout.readLine();
		var repoInfo:RepoInfo = {
            user: "",
            repo: ""
        }
        var sshRegex = ~/git@github.com:(.+)\/(.+).git/i;
        var urlRegex = ~/https:\/\/github.com\/(.+)\/(.+).git/i;

        var regex:EReg = null;
        
        if (sshRegex.match(originUrl))
            regex = sshRegex
        else if (urlRegex.match(originUrl))
            regex = urlRegex;

        if(regex!=null){
			repoInfo.user = regex.matched(1);
			repoInfo.repo = regex.matched(2);
        }
        
		// Generates a string expression
		return macro $v{repoInfo};
		#else
		// `#if display` is used for code completion. In this case returning an
		// empty string is good enough; We don't want to call git on every hint.
		var repoInfo:RepoInfo = {
			user: "riconuts",
			repo: "troll-engine"
		}
		return macro $v{repoInfo};
		#end
    }

    public static macro function getDefines() 
    {
        return macro $v{haxe.macro.Context.getDefines()};    
    }
}