// Written in the D Programming Language

// embd
// Copyright (C) 2013 Nathan M. Swan
// Available under the MIT (Expat) License

/++
 + Low-level API for embedding D code into text.
 + 
 + Copyright: Copyright © 2013 Nathan M. Swan
 + License: MIT (Expat) License
 + Authors: Nathan M. Swan
 +/
module embd;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.string;
import std.utf;

public:
/// The object which manages the rendering of an embd template.
/// 
/// To use, create a subclass, manually implement write, and
/// automatically implement render by mixin(renderer).
/// 
/// This allows you to access fields and other methods of your subclass
/// from the template (which is generated to be within the body of render).
interface Context {

    /// Write the content to whatever you are writing to.
    /// 
    /// Params:
    ///     content   = the text to write
    ///     evalCode  = what evaluation character occured after the start delimiter, 
    ///                 dchar.init if static content.
    ///                 
    /// Example:
    /// ---
    /// content        -> write("content", dchar.init);
    /// <%= expr() %>  -> write(expr(), '=');
    /// ---
    void write(string content, dchar evalCode);

    /// Renders the template. Don't implement this manually, instead
    /// mixin(renderer) in your subclass.
    /// 
    /// Params:
    ///     embd_code      = the embd template
    ///     embd_evalCodes = the allowed evaluation codes, passed to write
    ///                      to signal how to postprocess the dynamic content
    ///                      (e.g. whether to html escape or not)
    ///     embd_start     = the delimeter signalling the start of embedded code
    ///     embd_end       = the delimeter signalling the end of embedded code
    void render(string embd_code, 
                const(dchar)[] embd_evalCodes,
                string embd_start, string embd_end)();

    /// The render implementation to mixin to your subclass.
    enum renderer = q{
        public void render(string embd_code,
                           const(dchar)[] embd_evalCodes=`=`,
                           string embd_start=`<%`, string embd_end=`%>`
                           )() {
            mixin(createRenderingCode(embd_code, embd_start, embd_end, embd_evalCodes));
        }
    };
}

private:
unittest {
    static class MyContext : embd.Context {
        uint until = 20;

        void write(string content, dchar evalCode) {
            import std.stdio;
            write(content);
        }

        mixin(renderer);
    }

    auto ctx = new MyContext();
    ctx.render!(import("test.embd.html"), `=`)();
}

string createRenderingCode(string embd_code, 
                           string embd_start, string embd_end, 
                           const(dchar)[] embd_evalCodes) {
    // convert to dstring for slicing
    dstring inCode = embd_code.to!dstring();
    dstring startDelim = embd_start.to!dstring();
    dstring endDelim = embd_end.to!dstring();
    string outCode = "";

    // two states: static content and dynamic content
    dstring staticBuffer = "";
    while (!inCode.empty) {
        if (inCode.startsWith(startDelim)) {
            outCode ~= `write(`~generateQuotesFor(staticBuffer)~`, dchar.init);`;
            staticBuffer = "";
            outCode ~= getDynamicContent(inCode, startDelim, endDelim, embd_evalCodes);
        } else {
            staticBuffer ~= inCode.front;
            inCode.popFront();
        }
    }
    if (staticBuffer.length) {
        outCode ~= `write(`~generateQuotesFor(staticBuffer)~`, dchar.init);`;
    }

    return outCode.to!string();
}

string getDynamicContent(ref dstring inCode, 
                         dstring startDelim, dstring endDelim, 
                         const(dchar)[] evalCodes) {
    // TODO allow endDelim to appear in strings
    void notEmpty() {
        enforce(!inCode.empty, 
                xformat("Starting '%s' not matched by closing '%s'.", startDelim, endDelim));
    }

    inCode = inCode[startDelim.length .. $];
    notEmpty();
    dchar evalCode = dchar.init;
    if (evalCodes.canFind(inCode.front)) {
        evalCode = inCode.front;
        inCode.popFront();
    }
    string outCode = "";
    while (true) {
        notEmpty();
        if (inCode.startsWith(endDelim)) {
            inCode = inCode[endDelim.length .. $];
            break;
        } else {
            outCode ~= inCode.front.to!string();
            inCode.popFront();
        }
    }

    if (evalCode == dchar.init) {
        return outCode;
    } else {
        return xformat(`write(%s, '\u%.4x');`, outCode, evalCode);
    }
}

unittest {
    assert(generateQuotesFor(` `) == `x"20"c`);
    assert(generateQuotesFor(`ẍ`) == `x"e1ba8d"c`);
}

string generateQuotesFor(dstring buffer) {
    // convert to ubyte so it doesn't convert back into a range of dchars
    return xformat(`x"%-(%.2x%)"c`, cast(immutable(ubyte)[])buffer.to!string());
}