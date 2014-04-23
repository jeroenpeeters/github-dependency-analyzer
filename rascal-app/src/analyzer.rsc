module analyzer

import Prelude;
import IO;

loc datadir = |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/github-data|;

alias CountingMap = map[str, int];

public void analyzer(){
	files = crawl(datadir);
	iprintln(size(files));
	
	CountingMap cm = ();
	set[str] pom_projects = {};
	set[str] gradle_projects = {};
	set[str] ivy_projects = {};
	
	for(file <- files){
		if(contains(file.path, "2013")){
			continue;
		}
		str content = readFile(file);
	    
		switch(file.extension){
	    		case "poms": {
	    			cm = addAll(cm, artifactsFromPom(content)); 
	    			pom_projects += file.file;
	    		}
	    		case "gradles":{
	    			cm = addAll(cm, artifactsFromGradle(content));
	    			gradle_projects += file.file;
	    		}
	    		//case "buildxmls":	cm = addAll(cm, artifactsFromBuildXml(content));
	    		case "ivys": {
	    			cm = addAll(cm, artifactsFromIvy(content));
	    			ivy_projects += file.file;
	    		}
	    	}
	}
	
	println(size(cm));
	
	cm = (k:cm[k] | k <- cm, !contains(k, "maven"), !contains(k, "gradle"), !contains(k, "ivy")); // remove all build-style dependencies
	
	sorted = sort(toList(cm), sortOnSnd);
	iprintln(sorted);
	//println(size(cm));
	println("Analyzed projects: <size(pom_projects) + size(gradle_projects) + size(ivy_projects)>");
	println("Pom projects: <size(pom_projects)>");
	println("Gradle projects: <size(gradle_projects)>");
	println("Ivy projects: <size(ivy_projects)>");
	
	makeFrequencyFile(sorted);
	
}

private void makeFrequencyFile(list[tuple[str,int]] items){
	str s = "project\tfrequency\n";
	for(<k,n> <- items){
		s += "<k>\t<n>\n";
	}
	writeFile(|file:///home/jpeeters/Desktop/frequency.tsv|, s);
}

private void makeWordCloudFile(list[tuple[str,int]] items){
	str s = "";
	for(<k,n> <- items){
		int i = 0;
		while( i < n/10){
			s += k +" ";
			i += 1;
		}
	}
	writeFile(|file:///home/jpeeters/Desktop/wordCloud.txt|, s);
}

private CountingMap addAll(CountingMap cm, set[str] s){
	for(x <- s){
		cm = add(cm, x);
	}
	return cm;
}
private set[str] artifactsFromPom(str pom) = {artifactId | /artifactId\><artifactId:[\w\-_]+>\</ := pom};
private set[str] artifactsFromGradle(str gradle) = 
	{artifactId | /name:\s?'<artifactId:[\w\-_]+>'/ := gradle} +
	{artifactId | /libraries\.<artifactId:[\w\-_]+>/ := gradle} +
	{artifactId | /:<artifactId:[a-z][\w\-_]+>/ := gradle};
private set[str] artifactsFromBuildXml(str bxml) = 
	{artifactId | /dependency.+name="<artifactId:[\w\-_]+>"/ := bxml};
private set[str] artifactsFromIvy(str ivy) = artifactsFromBuildXml(ivy);

private list[loc] crawl(loc dir){
	res = [];
	for(str entry <- listEntries(dir)){
		loc sub = dir + entry;   
		if(isDirectory(sub)) {
	    	res += crawl(sub);
	  	} else {
	  		res += [sub]; 
	  	}
	};
 	return res;
}

private CountingMap add(CountingMap cm, str item){
	if(item in cm){
		cm[item] += 1;
	}else{
		cm[item] = 1;
	}
	return cm;
}

private bool sortOnSnd(tuple[&A a, &B b] t1, tuple[&A a, &B b] t2) = t1.b > t2.b;