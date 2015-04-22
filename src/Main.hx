import haxe.Json;
import sys.io.File;
import sys.io.Process;
import yaml.Yaml;
using thx.Arrays;
using thx.Strings;
using StringTools;
import thx.Objects;

class Main {
  static var libraryListFile = "data/libraries.json";
  static var requirementListFile = "data/requirements.json";
  static var docHxmlFile = "data/doc.hxml";
  static function main() {
    new Main();
  }

  var haxelibPath : String;
  var dataPath : String;
  var build_doc : Array<String>;
  var tmp : String;
  var cwd : String;
  var libraryInfo : Array<{ info : Dynamic, readme : String }>;
  public function new() {

    // store haxelib
    cwd = Sys.getCwd();
    var originalHaxelibPath = getHaxelibPath(),
        requirements : Array<{ name : String }> = Json.parse(File.getContent(requirementListFile)),
        libraries : Array<{ name : String }> = Json.parse(File.getContent(libraryListFile));

    tmp = '${cwd}tmp/';

    build_doc = [];
    haxelibPath = '${tmp}haxelib/';

    cleanDir(tmp);

    var success = true;
    try {
      // move haxelib
      setHaxelibPath(haxelibPath);

      // install requirements
      requirements.pluck(haxelibInstall(_.name));

      libraryInfo = libraries.pluck(library(_.name));
      // assemble doc
      assembleDocHxml();
      // generate doc xml
      generateDocXml();

    } catch(e : Dynamic) {
      trace('something went wrong: $e');
      success = false;
    }

    // restore haxelib
    setHaxelibPath(originalHaxelibPath);
    if(!success) return;

    // generate doc pages
    generatePages();

    // copy assets
    copyDocPages();

    // generate projects info
    generateProjectsInfo();

    // generate project doc
    generateProjectsDoc();
  }

  function generateProjectsDoc() {
    var path = "../thxlib.github.io/lib/";
    cleanDir(path);
    libraryInfo.map(function(item) {
      var info = {
        layout : "library",
        title : item.info.name
      };
      Objects.tuples(item.info).map(function(t) {
        Reflect.setField(info, t._0, t._1);
      });
      var content = '---
${Yaml.render(info)}
---

${item.readme}';
      ensureDir('${path}${item.info.name}/');
      File.saveContent('${path}${item.info.name}/index.md', content);
    });
  }

  function generateProjectsInfo() {
    var info = libraryInfo.pluck(_.info),
        yaml = Yaml.render(info);

      File.saveContent('../thxlib.github.io/_data/libraries.yml', yaml);
  }

  function assembleDocHxml() {
    var doc = build_doc.join("\n") + "\n" + File.getContent(docHxmlFile);
    File.saveContent('$tmp/doc.hxml' , doc);
  }

  function generateDocXml() {
    ensureDir('${tmp}xml');
    runHaxe(['$tmp/doc.hxml']);
  }

  function generatePages() {
    Sys.command("./dox", [
      "--output-path", '${tmp}pages',
      "--input-path", '${tmp}xml',
      //"--template-path", '',
      //"--resource-path", '', // can repeat
      "--toplevel-package", "thx",
      "-theme", '${cwd}/theme/thx/',
      "--title", "thx libraries",
      "--include", "thx",
      "--define", "source-path", "/go/#"
    ]);
  }

  function copyDocPages() {
    Sys.command("rm", ["-rf", "../thxlib.github.io/api"]);
    Sys.command("cp", ["-r", '${tmp}pages', "../thxlib.github.io/api"]);
  }

  function library(name : String) {
    var libname = name.split(".").slice(1).join("."),
        libpath = '$haxelibPath${name.replace(".", ",")}/';
    haxelibInstall(name);

    var version = File.getContent('$libpath.current'),
        currentlibpath = '$libpath${version.replace(".", ",")}/',
        haxelib = Json.parse(File.getContent('${currentlibpath}haxelib.json'));

    haxelib.path = StringTools.replace(haxelib.name, "." , "/");

    build_doc.push('-lib $name');
    build_doc.push('-cp ${currentlibpath}doc/');
    build_doc.push('Import${libname.capitalize()}');

    return {
      info : haxelib,
      readme : File.getContent('${currentlibpath}README.md')
    };
  }

  static function getHaxelibPath() : String {
    var proc = new Process("haxelib", ["config"]),
        path = proc.stdout.readLine();
    proc.close();
    return path;
  }

  static function setHaxelibPath(path : String) {
    Sys.command("haxelib", ['setup', path]);
  }

  static function haxelibInstall(lib : String) {
    Sys.command("haxelib", ['install', lib]);
  }

  static function haxelibRun(commands : Array<String>) {
    Sys.command("haxelib", ["run"].concat(commands));
  }

  static function cleanDir(path : String) {
    Sys.command("rm", ["-rf", path]);
    ensureDir(path);
  }

  static function ensureDir(path : String) {
    Sys.command("mkdir", ["-p", path]);
  }

  static function runHaxe(options : Array<String>) {
    Sys.command("haxe", options);
  }
}