import SwiftUI
import WebKit

// MARK: - Language ID Mapping (Monaco language IDs)

func monacoLanguage(for ext: String) -> String {
    switch ext {
    case "swift":              return "swift"
    case "py", "pyw":          return "python"
    case "js":                 return "javascript"
    case "jsx":                return "javascriptreact"
    case "ts":                 return "typescript"
    case "tsx":                return "typescriptreact"
    case "html", "htm":        return "html"
    case "css":                return "css"
    case "scss", "sass":       return "scss"
    case "less":               return "less"
    case "json":               return "json"
    case "yaml", "yml":        return "yaml"
    case "xml":                return "xml"
    case "toml":               return "ini"
    case "md", "mdx":          return "markdown"
    case "sh", "zsh", "bash",
         "fish", "nu":         return "shell"
    case "rs":                 return "rust"
    case "go":                 return "go"
    case "java":               return "java"
    case "kt", "kts":          return "kotlin"
    case "cs":                 return "csharp"
    case "fs":                 return "fsharp"
    case "cpp", "cxx", "cc",
         "c", "h", "hpp":      return "cpp"
    case "rb":                 return "ruby"
    case "php":                return "php"
    case "lua":                return "lua"
    case "sql":                return "sql"
    case "dockerfile":         return "dockerfile"
    case "graphql", "gql":     return "graphql"
    case "vue":                return "html"
    case "tf", "tfvars":       return "hcl"
    case "r":                  return "r"
    case "dart":               return "dart"
    case "ex", "exs":          return "elixir"
    default:                   return "plaintext"
    }
}

// MARK: - Monaco Editor View

struct MonacoEditorView: NSViewRepresentable {
    /// The UUID of the currently active file — changing this triggers a content reload.
    let fileID:  UUID
    /// The content to display (used when fileID changes).
    let content: String
    /// Monaco language identifier.
    let language: String
    /// Called (debounced 250 ms) whenever the user edits content.
    let onContentChange: (String) -> Void

    // MARK: Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MonacoEditorView
        weak var webView: WKWebView?

        /// Guards against acting on our own programmatic setValue() triggering onDidChangeModelContent.
        var currentFileID: UUID? = nil
        var isReady       = false
        /// Content queued before the editor was ready.
        var pendingSet: (String, String)? = nil

        init(_ parent: MonacoEditorView) { self.parent = parent }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "editorReady":
                isReady = true
                if let (c, l) = pendingSet {
                    applyContent(c, language: l)
                    pendingSet = nil
                }
            case "contentChanged":
                guard let text = message.body as? String else { return }
                DispatchQueue.main.async { self.parent.onContentChange(text) }
            default:
                break
            }
        }

        // MARK: Content Injection

        func applyContent(_ content: String, language: String) {
            guard let wv = webView, isReady else {
                pendingSet = (content, language)
                return
            }
            // Base64-encode to safely pass arbitrary text across the JS bridge.
            let b64 = Data(content.utf8).base64EncodedString()
            let js  = "window.applyFile('\(b64)', '\(language)');"
            wv.evaluateJavaScript(js) { _, err in
                if let err { print("[Monaco] applyFile error: \(err)") }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let ctrl = WKUserContentController()
        ctrl.add(context.coordinator, name: "editorReady")
        ctrl.add(context.coordinator, name: "contentChanged")

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ctrl
        // Allow file access and inline JS — needed for local resources
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = false

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.setValue(false, forKey: "drawsBackground") // Transparent before load

        context.coordinator.webView = wv
        wv.loadHTMLString(monacoHTML, baseURL: nil)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let coord = context.coordinator
        guard coord.currentFileID != fileID else { return }
        coord.currentFileID = fileID
        coord.applyContent(content, language: language)
    }
}

// MARK: - Embedded Monaco HTML

private let monacoHTML = #"""
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
*,html,body{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;background:#0f0f10;overflow:hidden}
#root{width:100%;height:100%}
#loading{
  position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  color:#383838;font:14px/1 "SF Pro Text",system-ui,sans-serif;
  pointer-events:none;
}
</style>
</head>
<body>
<div id="loading">Loading editor…</div>
<div id="root"></div>
<script>
var require={paths:{vs:'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs'}};
</script>
<script src="https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs/loader.js"
        onerror="document.getElementById('loading').textContent='Editor failed to load – check internet connection.'">
</script>
<script>
var isExt=false,debTimer=null,ed=null;

require(['vs/editor/editor.main'],function(){
  monaco.editor.defineTheme('multiterm',{
    base:'vs-dark',inherit:true,rules:[],
    colors:{
      'editor.background':'#0f0f10',
      'editor.lineHighlightBackground':'#18181d',
      'editorGutter.background':'#0f0f10',
      'editorLineNumber.foreground':'#333340',
      'editorLineNumber.activeForeground':'#5a5a70',
      'editor.selectionBackground':'#26406088',
      'editorIndentGuide.background':'#1e1e28',
      'editorIndentGuide.activeBackground':'#303042',
    }
  });

  ed=monaco.editor.create(document.getElementById('root'),{
    value:'',
    language:'plaintext',
    theme:'multiterm',
    fontSize:13,
    fontFamily:"Menlo,'Cascadia Code','JetBrains Mono',Consolas,monospace",
    fontLigatures:true,
    lineNumbers:'on',
    lineNumbersMinChars:4,
    minimap:{enabled:true,renderCharacters:false,scale:1},
    scrollBeyondLastLine:false,
    automaticLayout:true,
    tabSize:4,insertSpaces:true,
    wordWrap:'off',
    renderWhitespace:'selection',
    cursorBlinking:'smooth',
    cursorSmoothCaretAnimation:'on',
    smoothScrolling:true,
    padding:{top:14,bottom:14},
    bracketPairColorization:{enabled:true},
    guides:{bracketPairs:true,indentation:true},
    'semanticHighlighting.enabled':true,
    suggest:{showStatusBar:false},
    scrollbar:{verticalScrollbarSize:8,horizontalScrollbarSize:8},
  });

  // Debounced change notification to Swift
  ed.onDidChangeModelContent(function(){
    if(isExt)return;
    clearTimeout(debTimer);
    debTimer=setTimeout(function(){
      window.webkit.messageHandlers.contentChanged.postMessage(ed.getValue());
    },250);
  });

  // Called from Swift: base64-encoded content + Monaco language id
  window.applyFile=function(b64,lang){
    try{
      isExt=true;
      var content=atob(b64);
      var model=ed.getModel();
      if(model)monaco.editor.setModelLanguage(model,lang);
      ed.setValue(content);
      ed.setScrollPosition({scrollTop:0,scrollLeft:0});
      setTimeout(function(){isExt=false;},20);
    }catch(e){console.error(e);isExt=false;}
  };

  // Called from Swift to retrieve current content (for immediate save)
  window.getContent=function(){return ed?ed.getValue():'';};

  document.getElementById('loading').style.display='none';
  window.webkit.messageHandlers.editorReady.postMessage('ready');
});
</script>
</body>
</html>
"""#
