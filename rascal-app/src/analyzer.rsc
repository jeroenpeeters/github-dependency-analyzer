module analyzer

import Prelude;
import IO;

//loc datadir = |file:///home/jpeeters/Desktop/gitdata|;
loc datadir = |file:///home/jpeeters/Desktop/gittest/data|;

alias CountingMap = map[str, int];

public void analyzer(){
	files = crawl(datadir);
	iprintln(size(files));
	
	CountingMap cm = ();
	for(file <- files){
	    str content = readFile(file);
	    
	    switch(file.extension){
	    	case "poms": 		cm = addAll(cm, artifactsFromPom(content));
	    	case "gradles":		cm = addAll(cm, artifactsFromGradle(content));
	    	//case "buildxmls":	cm = addAll(cm, artifactsFromBuildXml(content));
	    	case "ivys":		cm = addAll(cm, artifactsFromIvy(content));
	    }
	}
	
	iprintln(sort(toList(cm), sortOnSnd)[0..20]);
	println(size(cm));
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