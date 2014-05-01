module analyzer

import Prelude;
import IO;

//example: analyze(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/github-data|, |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/results|)

alias CountingMap = map[str, int];

public void analyze(loc datadir, loc resultdir){
	// list all project files
	files = [f | f <- crawl(datadir), !contains(f.path, "2013")];
	
	CountingMap cm = ();
	set[str] pom_projects = {};
	set[str] gradle_projects = {};
	set[str] ivy_projects = {};
	
	for(file <- files){
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
	    		case "ivys": {
	    			cm = addAll(cm, artifactsFromIvy(content));
	    			ivy_projects += file.file;
	    		}
	    	}
	}
	
	println(size(cm));
	
	cm = (k:cm[k] | k <- cm, !contains(k, "maven"), !contains(k, "gradle"), !contains(k, "ivy")); // remove all build-style dependencies
	
	sorted = sort(toList(cm), sortOnSnd);
	//iprintln(sorted);
	println("Analyzed projects: <size(pom_projects) + size(gradle_projects) + size(ivy_projects)>");
	println("Pom projects: <size(pom_projects)>");
	println("Gradle projects: <size(gradle_projects)>");
	println("Ivy projects: <size(ivy_projects)>");
	
	makeFrequencyFile(resultdir + "/frequency.tsv", sorted);
}

private void makeLatexTable(list[tuple[str,int]] items){
	items = items[..100];
	str s = "\\begin{tabular}{ | l | l | }\n    \\hline\n";
	for(<k,n> <- items){
		s += "    <k> & <n> \\\\ \\hline\n";
	}
	s += "\\end{tabular}";
	println(s);
}

private void makeFrequencyFile(loc file, list[tuple[str,int]] items){
	str s = "project\tfrequency\n";
	for(<k,n> <- items){
		s += "<k>\t<n>\n";
	}
	writeFile(file, s);
}

private void makeWordCloudFile(loc file, list[tuple[str,int]] items){
	str s = "";
	for(<k,n> <- items){
		int i = 0;
		while( i < n/10){
			s += k +" ";
			i += 1;
		}
	}
	writeFile(file, s);
}

private set[str] artifactsFromPom(str pom) = {artifactId | /artifactId\><artifactId:[\w\-_]+>\</ := pom};
private set[str] artifactsFromGradle(str gradle) = 
	{artifactId | /name:\s?'<artifactId:[\w\-_]+>'/ := gradle} +
	{artifactId | /libraries\.<artifactId:[\w\-_]+>/ := gradle} +
	{artifactId | /:<artifactId:[a-z][\w\-_]+>/ := gradle};
private set[str] artifactsFromBuildXml(str bxml) = {artifactId | /dependency.+name="<artifactId:[\w\-_]+>"/ := bxml};
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

private CountingMap addAll(CountingMap cm, set[str] items){
	for(item <- items){
		cm = add(cm, item);
	}
	return cm;
}
private CountingMap add(CountingMap cm, str item){
	if(item in cm){
		cm[item] += 1;
	}else{
		cm[item] = 1;
	}
	return cm;
}

// sort on second item in tuple
private bool sortOnSnd(tuple[&A a, &B b] t1, tuple[&A a, &B b] t2) = t1.b > t2.b;