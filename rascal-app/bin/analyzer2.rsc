module analyzer2

import Prelude;
import IO;

//example: analyze(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/github-data|, |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/results|)

public data DependencyTool = maven() | gradle() | ivy();
public data DependencyScope = compileScope() | testScope();
public data Dependency = dependency(str name, DependencyTool fromTool, DependencyScope scope);

public data AnalyzedFile = fileWithDependencies(loc path, set[Dependency] dependencies);

public set[Dependency] compileScope(set[Dependency] dependencies) = filterOnScope(dependencies, compileScope());
public set[Dependency] testScope(set[Dependency] dependencies) = filterOnScope(dependencies, testScope());
private set[Dependency] filterOnScope(set[Dependency] dependencies, DependencyScope scope) = { d | d:dependency(_ , _, scope) <- dependencies };

alias CountingMap = map[str, int];

public void x(){
	loc f = |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/data/2012-06-26/puniverse_galaxy.gradles|;
	y = gradleDependencies(readFile(f));
	println(y);
	println("compileScope:  <size(compileScope(y))>");
	println("testScope:  <size(testScope(y))>");
}

public void analyze(loc datadir, loc resultdir){
	files = [f | f <- crawl(datadir)];
	list[AnalyzedFile] analyzedFiles = [ analyze(file.extension, file, readFile(file)) | file <- files, includeFile(file.extension)];
	//list[Dependency] deps = joinLists([dependencies(file.extension, file, readFile(file)) | file <- files ]);
	
	// find files that have no dependencies; dependencies is empty set
	list[AnalyzedFile] fileWithoutDeps = [f | f:fileWithDependencies(_, {}) <- analyzedFiles];
 	
 	// some stats about the analyzed files
	println("fileWithoutDependencies:  <size(fileWithoutDeps)>");
	
	set[Dependency] allDeps 	= ({} | it + e | fileWithDependencies(_, e) <- analyzedFiles);
	set[Dependency] compileDeps = compileScope(allDeps);
	set[Dependency] testDeps 	= testScope(allDeps);
	// some stats about all dependencies
	println("Total deps  : <size(allDeps)>");
	println("Compile deps: <size(compileDeps)>");
	println("Test deps   : <size(testDeps)>");
	
	
}

private bool includeFile("trees") = false;
private bool includeFile("nobuild") = false;
private bool includeFile("buildxmls") = false;
private bool includeFile(_) = true;

private AnalyzedFile analyze("gradles", loc path, content) = fileWithDependencies(path, gradleDependencies(content));
private AnalyzedFile analyze("poms", loc path, content) = fileWithDependencies(path, pomDependencies(content));
private AnalyzedFile analyze("ivys", loc path, content) = fileWithDependencies(path, ivyDependencies(content));

private list[Dependency] joinLists(list[list[Dependency]] x) = ([] | it + e | e <- x);

private set[Dependency] ivyDependencies(str content) {
	deps = {};
	for (dep <- [ dep | /(?ms)\<dependency<dep:((?!\>).)+>\>/ := content ] ){
		DependencyScope scope = compileScope();
		if (/conf=.+test/ := dep){
			scope = testScope();
		}
		if (/name=\"<name:.+?>\"/ := dep && /org=\"<org:.+?>\"/ := dep){
			deps += dependency("<org>:<name>", ivy(), scope);
		}
	}
	return deps;
}

private set[Dependency] gradleDependencies(str content) =
	{dependency("<groupId>:<artifactId>", gradle(), testScope()) | /testCompile.+"<groupId:[a-z][\w\-_\.]+>:?<artifactId:[a-z][\w\-_]+>/ := content} +
	{dependency("<groupId>:<artifactId>", gradle(), compileScope()) | /(compile|runtime).+"<groupId:[a-z][\w\-_\.]+>:?<artifactId:[a-z][\w\-_]+>/ := content};

private set[Dependency] pomDependencies(str content) {
	deps = {};
	for (dep <- [ dep | /(?ms)\<dependency\><dep:((?!dependency).)+>\<\/dependency\>/ := content ] ){
		DependencyScope scope = compileScope();
		if (/\<scope\>test\<\/scope\>/ := dep){
			scope = testScope();
		}
		if (/\<artifactId\><artifactId:.+>\<\/artifactId\>/ := dep && /\<groupId\><groupId:.+>\<\/groupId\>/ := dep){
			deps += dependency("<groupId>:<artifactId>", maven(), scope);
		}
	}
	return deps;
}

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