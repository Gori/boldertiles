Let's rework the whole "reine with claude" thing. I want something better. Much better.

* Each notes tile should be able to have a status "idle", "active" or "waiting"
* This should be visible somewhere.
* Idle = Just a normal notes tile. Users can just write whatever. It's just a normal note. This is where it starts.
* Active = Being investigated / grown / marinated / refined by our system.
* Waiting = Has been investigated a few times and thinks it's time for the user to continue rather than for us to just be thinking about it.

The thing we want here is that each tile should be able to "marinate / showerthought" whatever - basically think about our notes while we're not working on them. It should use Claude Code to do this in a way that is actually relevant to the current project.

The user should be able to input any type of idea. Short, small, just a sentence. Several things at once.

Once an idea / thought / whatever is marked as done it is promoted to our Features tile. This is a tile that there only is one of, and it lists all our ready ideas.

The user can keep refining ideas however much they want.

The system periodically checks and moves forward with the ideas that are marked as "active".

The visual suggestions / discussions in the notes tile should be reminiscent of diff's in a git repository. We need to talk about this, to figure out the best UX.

An idea can be moved forward in many steps.

The features tile is on top of all other tiles, and can be reached by swiping up. THe features tile also contains all main information about the whole project. Features, once they are complete features, can be sent to a new Claude COde tile, or the description of what they are can be copied so the user can send it to Claude Code herself.