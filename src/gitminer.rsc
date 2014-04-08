module gitminer

import Prelude;
import ParseTree;
import util::ShellExec;

public void minegit(){
	set[str] githubRepos = {};
	for(int i <- [1 .. 11]){
		content = searchGithubJavaRepo(i, 100);
		githubRepos += getGithubRepoUrls(content);
		println("GithubSearch:: page <i> <size(githubRepos)>");
	}
	
	println(githubRepos);
	println(size(githubRepos));
	
	set[str] artifacts = {};
	
	int counter = 0;
	for(str repoUrl <- githubRepos){
		artifacts += process(repoUrl);
		counter += 1;
		if(counter%10 == 0) println("Processed Repo\'s: <counter>, Unique dependencies: <size(artifacts)>");
	}
}


private set[str] process(str repoUrl){
	name = replaceAll(repoUrl[size("https://api.github.com/repos/")..], "/", "_");
	set[str] artifacts = {};
	// TODO; count each dependency only once when it occurs multiple times per project
	content = readFromUrl(repoUrl + "/git/refs/heads/master");
	sha = getSha(content);
	if(sha != ""){
		tree = readFromUrl(repoUrl + "/git/trees/<sha>?recursive=1");
		sha2_pom_set 	= {sha2 | /"sha":\s?"<sha2:[a-z0-9]+>",\s+"path":\s?"<path:[\w\/\-_]*pom.xml>/ 			:= tree};
		sha2_gradle_set = {sha2 | /"sha":\s?"<sha2:[a-z0-9]+>",\s+"path":\s?"<path:[\w\/\-_]*build.gradle>/ 	:= tree};
		for(sha2 <- sha2_pom_set) 		downloadBlob(repoUrl, sha2, "<name>.poms");
		for(sha2 <- sha2_gradle_set) 	downloadBlob(repoUrl, sha2, "<name>.gradles");
		if(size(sha2_pom_set) == 0 && size(sha2_gradle_set) == 0) println("No build files <repoUrl>/git/trees/<sha>?recursive=1"); 
	}
	return artifacts;
}

private void downloadBlob(str repoUrl, str sha2, str toFile){
	blob = readFromUrl(repoUrl + "/git/blobs/<sha2>");
	if( /"content":\s?"<base64:[\w\\n\+\=]+>/ := blob){
		writeFile(|file:///tmp/gitminer_base64|, base64);
		createProcess("/bin/bash", ["/home/jpeeters/Desktop/decodeBase64.bash", "/tmp/gitminer_base64", "/home/jpeeters/Desktop/gitdata/<toFile>"]);
		//artifacts += {artifactId | /artifactId\><artifactId:[\w\-_]+>\</ := d};
	}
}

private str searchGithubJavaRepo(int page, int max_per_page) 
	= readFromUrl("https://api.github.com/search/repositories?q=language:java&sort=stars&order=desc&per_page=<max_per_page>&page=<page>");

private set[str] getGithubRepoUrls(str content) = {url | /"url":\s?"<url:https:\/\/api.github.com\/repos\/((?!").)+>/ := content};
private str getSha(str content) { 
	if( /"sha":\s?"<sha:[a-z0-9]+>/ := content) return sha;
	return "";
}

private str joinStrings(list[str] l){
	str result = "";
	for(str s <- l) result += s;
	return result;
}

private str readFromUrl(str url) = readEntireStream(createProcess("curl", ["-u", "jeroen@peetersweb.nl:qwXFlJcGS2UAnD39Y2uf", url]));
