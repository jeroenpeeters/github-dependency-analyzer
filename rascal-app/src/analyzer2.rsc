module analyzer2

import Prelude;
import IO;

//example: analyze(|file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/github-data|, |file:///home/jpeeters/Documents/code/github/github-dependency-analyzer/results|)

public data DependencyTool = maven() | gradle() | ivy();
public data DependencyScope = compileScope() | testScope();
public data Dependency = dependency(str name, DependencyTool fromTool, DependencyScope scope)	
			| noDependencies(loc file)
			| unknownFile(loc file);

public data AnalyzedFile = fileWithDependencies(loc path, set[Dependency] dependencies)
			| fileWithoutDependencies(loc path)
			| unknownFile(loc path);

alias CountingMap = map[str, int];

public void x(){
	loc f = |file:///home/jpeeters/Desktop/test.txt|;
	y = dependencies("poms", f, readFile(f));
	println(y);
}

public void analyze(loc datadir, loc resultdir){
	files = [f | f <- crawl(datadir)];
	list[AnalyzedFile] analyzedFiles = [ analyze(file.extension, file, readFile(file)) | file <- files, includeFile(file.extension)];
	//list[Dependency] deps = joinLists([dependencies(file.extension, file, readFile(file)) | file <- files ]);
	
	println("unknown files: <size([f | unknownFile(f) <- analyzedFiles])>");
	
	//println("deps: <(0 | it + 1 | dependency(_, _, _) <- deps)>");
	//println("no deps: <(0 | it + 1 | noDependencies(file) <- deps)>");
	//println("unknownFiles: <(0 | it + 1 | unknownFile(file) <- deps)>");
 	for (unknownFile(file) <- analyzedFiles){
 		println(file);
 	}
}

private bool includeFile("trees") = false;
private bool includeFile("nobuild") = false;
private bool includeFile("buildxmls") = false;
private bool includeFile(_) = true;

//private AnalyzedFile = analyze("gradles", loc path, str content) = ;

private AnalyzedFile analyze("gradles", loc path, _) = fileWithoutDependencies(path);
private AnalyzedFile analyze("poms", loc path, _) = fileWithoutDependencies(path);
private AnalyzedFile analyze("ivys", loc path, _) = fileWithoutDependencies(path);
private AnalyzedFile analyze("buildxmls", loc path, _) = fileWithoutDependencies(path);
private AnalyzedFile analyze(_, loc path, _) = unknownFile(path);

private list[Dependency] joinLists(list[list[Dependency]] x) = ([] | it + e | e <- x);
private list[Dependency] hasDependencies(list[Dependency] deps, loc file) = size(deps) > 0 ? deps : [noDependencies(file)];

private list[Dependency] dependencies("gradles", loc file, str content) =
	hasDependencies(
		[dependency(artifactId, gradle(), testScope()) | /testCompile.+:<artifactId:[a-z][\w\-_]+>/ := content] +
		[dependency(artifactId, gradle(), compileScope()) | /compile.+:<artifactId:[a-z][\w\-_]+>/ := content] +
	, file);

private list[Dependency] dependencies("poms", loc file, str content) {
	deps = [];
	for (dep <- [ dep | /(?ms)\<dependency\><dep:((?!dependency).)+>\<\/dependency\>/ := content ] ){
		DependencyScope scope = compileScope();
		name = "";
		if (/\<artifactId\><artifactId:.+>\<\/artifactId\>/ := dep){
			name = artifactId;
		}
		if (/\<scope\>test\<\/scope\>/ := dep){
			scope = testScope();
		}
		deps += dependency(name, maven(), scope);
	}
	return deps;
}
private list[Dependency] dependencies("trees", _, _) = [];
private list[Dependency] dependencies(_, loc file, _) = [unknownFile(file)];

private set[str] artifactsFromPom(str pom) = {artifactId | /artifactId\><artifactId:[\w\-_]+>\</ := pom};
private set[str] artifactsFromGradle(str gradle) = 
	//{artifactId | /name:\s?'<artifactId:[\w\-_]+>'/ := gradle} +
	//{artifactId | /libraries\.<artifactId:[\w\-_]+>/ := gradle} +
	{artifactId | /compile.+:<artifactId:[a-z][\w\-_]+>/ := gradle};
private set[str] testArtifactsFromGradle(str gradle) = 
	{artifactId | /testCompile.+:<artifactId:[a-z][\w\-_]+>/ := gradle};
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