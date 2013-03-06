embd
====
A low-level API for embedding D code into text.

Installation
------------
If you have [dub](http://github.com/rejectedsoftware/dub/) installed, you can
just add `embd` as a dependency. Otherwise, just take the file `source/embd.d`
and drop it into wherever you need it; it's a top-level module. 

Tutorial
--------
First, create and save a template:

    <% import markdown; %>
    <!DOCTYPE html>
    <html>
      <head>
        <title><%= title %></title>
      </head>
      <body>
        <h1>User Profile: <%= username %></h1>
        <h2>About Me:</h2>
        <p>
          <%! renderMarkdown(biography) %>
        </p>
      </body>
    </html>

We will go back to what the various means of embedding code are later. Now, to
use it, create a subclass of `embd.Context` that holds all the state variables:

    class UserProfile : embd.Context {
        string username, title, biography;
        
        mixin(renderer);
        
        void write(string content, dchar evalCode) {
            if (evalCode == '=') {
                content = htmlEscape(content);
            }
            writeString(content);   
        }
    }

To use this class, just initialize it, set the state variables, and call the
render function passing the embd template as a compile-time argument:

    auto temp = new UserProfile();
    
    temp.username = dbEntry.username;
    temp.title = dbEntry.title;
    temp.biography = dbEntry.biography;
    
    temp.render!(import("userprofile.embd.html"), `!=`, `<%`, `%>`)();

Metaprogramming magic will turn the render function into a series of `write`
calls:

    - the text between the embedded D is called "static content," so it
      produces this call:
        
        write("{static content}", dchar.init);
      
    - the D code with a special character in front of the embedding
      delimeters is evaluated as a string expression, and the special
      character is passed as a `dchar`:
      
        write({expression}, {special character});
        
      This allows you to e.g. distinguish between html text that should
      be escaped or not (this is the only example I could think of).

    - the D code between the embedding delimeters without a special
      character afterwards is placed directly without modification.      
        
The latter case need not contain valid statements, so you can create control
structures:

    <% if (cond) { %>           if (cond) {
      Yay, cond is true!          write("Yay, cond is true!", dchar.init);
    <% } else { %>          =>  } else {
      Aww, cond is false!         write("Aww, cond is false!", dchar.init);
    <% } %>                     }
    
Code within the template is directly inside the render function, so it can
access the state variables and `this` refers to the `Context`.

Just an extra tidbit: you can customize the template language by choosing
the allowed eval codes and start/end delimeters as arguments to the `render`
function.

That's all folks.

License
-------
Copyright (C) 2013 Nathan M. Swan   
Available under the MIT (Expat) license, see LICENSE file.


 