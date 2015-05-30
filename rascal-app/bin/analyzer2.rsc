module analyzer2

import Prelude;
import IO;

//example: analyze(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/github-data|, |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/results|)

//public data DependencyTool = maven() | gradle() | ivy();
public data DependencyScope = compileScope() | testScope();
public data Dependency = dependency(str name, DependencyScope scope);

public data AnalyzedFile = dependencyFile(loc path, set[Dependency] dependencies);

public set[Dependency] compileScope(set[Dependency] dependencies) = filterOnScope(dependencies, compileScope());
public set[Dependency] testScope(set[Dependency] dependencies) = filterOnScope(dependencies, testScope());
private set[Dependency] filterOnScope(set[Dependency] dependencies, DependencyScope scope) = { d | d:dependency(_, scope) <- dependencies };

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
	list[AnalyzedFile] fileWithoutDeps = [f | f:dependencyFile(_, {}) <- analyzedFiles];
 	
 	// some stats about the analyzed files
	println("fileWithoutDependencies:  <size(fileWithoutDeps)>");
	
	set[Dependency] allDeps 	= ({} | it + e | dependencyFile(_, e) <- analyzedFiles);
	set[Dependency] compileDeps = compileScope(allDeps);
	set[Dependency] testDeps 	= testScope(allDeps);
	// some stats about all dependencies
	println("Total deps  : <size(allDeps)>");
	println("Compile deps: <size(compileDeps)>");
	println("Test deps   : <size(testDeps)>");
	
	map[Dependency, set[AnalyzedFile]] xmap = ();
	for(f:dependencyFile(_, deps) <- analyzedFiles){
		for(dep <- deps){
			if( dep in xmap ){
				xmap[dep] += f;
			}else{
				xmap[dep] = {f};
			}
		}
	}
	
	lrel[Dependency, int] compileDepsCount = mysort ( {<dep, size(xmap[dep])> | dep:dependency(_, compileScope()) <- xmap} );
	showFirstTen(compileDepsCount);
	
	lrel[Dependency, int] testDepsCount = mysort( {<dep, size(xmap[dep])> | dep:dependency(_, testScope()) <- xmap} );
	showFirstTen(testDepsCount);
	
	
	makeFrequencyFile(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/compileDepsFrequency.tsv|, compileDepsCount);
	makeFrequencyFile(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/testDepsFrequency.tsv|, testDepsCount);
	
	//println(size(xmap[dependency("junit:junit",testScope())]));
}

private	lrel[Dependency, int] mysort(rel[Dependency, int] depsCountMap) = sort(depsCountMap, sortOnSnd);

private void showFirstTen(lrel[Dependency, int] depsCountMap) = println(depsCountMap[0..10]);

private bool includeFile("trees") = false;
private bool includeFile("nobuild") = false;
private bool includeFile("buildxmls") = false;
private bool includeFile(_) = true;

private AnalyzedFile analyze("gradles", loc path, content) = dependencyFile(path, gradleDependencies(content));
private AnalyzedFile analyze("poms", loc path, content) = dependencyFile(path, pomDependencies(content));
private AnalyzedFile analyze("ivys", loc path, content) = dependencyFile(path, ivyDependencies(content));

private list[Dependency] joinLists(list[list[Dependency]] x) = ([] | it + e | e <- x);

private set[Dependency] ivyDependencies(str content) {
	deps = {};
	for (dep <- [ dep | /(?ms)\<dependency<dep:((?!\>).)+>\>/ := content ] ){
		DependencyScope scope = compileScope();
		if (/conf=.+test/ := dep){
			scope = testScope();
		}
		if (/name=\"<name:.+?>\"/ := dep && /org=\"<org:.*?>\"/ := dep){
			deps += dependency("<org>:<name>", scope);
		}
	}
	return deps;
}

private set[Dependency] gradleDependencies(str content) =
	{dependency("<groupId>:<artifactId>", testScope()) | /testCompile.+"<groupId:[a-z][\w\-_\.]+>:?<artifactId:[a-z][\w\-_]+>/ := content} +
	{dependency("<groupId>:<artifactId>", compileScope()) | /(compile|runtime).+"<groupId:[a-z][\w\-_\.]+>:?<artifactId:[a-z][\w\-_]+>/ := content};

private set[Dependency] pomDependencies(str content) {
	deps = {};
	for (dep <- [ dep | /(?ms)\<dependency\><dep:((?!dependency).)+>\<\/dependency\>/ := content ] ){
		DependencyScope scope = compileScope();
		if (/\<scope\>test\<\/scope\>/ := dep){
			scope = testScope();
		}
		if (/\<artifactId\><artifactId:.+>\<\/artifactId\>/ := dep && /\<groupId\><groupId:.+>\<\/groupId\>/ := dep){
			deps += dependency("<groupId>:<artifactId>", scope);
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

// sort on second item in tuple
private bool sortOnSnd(tuple[Dependency a, int b] t1, tuple[Dependency a, int b] t2) = t1.b > t2.b;


private void makeLatexTable(list[tuple[str,int]] items){
	items = items[..100];
	str s = "\\begin{tabular}{ | l | l | }\n    \\hline\n";
	for(<k,n> <- items){
		s += "    <k> & <n> \\\\ \\hline\n";
	}
	s += "\\end{tabular}";
	println(s);
}

private void makeFrequencyFile(loc file, lrel[Dependency, int] deps){
	str s = "project\tfrequency\n";
	for(<dependency(name,_), count> <- deps){
		s += "<name>\t<count>\n";
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
