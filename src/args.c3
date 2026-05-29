// Whisker AO2 Server — Command Argument Parsing
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One place to turn the raw tail of an OOC command into a clean,
// quote-aware list of arguments. Every other AO server splits command
// arguments into a list before handing them to a command; Whisker now
// does the same so command code never has to re-implement splitting.
//
//   /ban 12 "ban evading" "3 days"
//        └────────────────────────┘  raw tail handed to parse()
//
//   tokens => [ "12", "ban evading", "3 days" ]   (3 tokens)
//
// Double or single quotes group whitespace into a single token. Bare
// runs are split on whitespace. Tokens are sub-slices of the original
// string — parsing allocates nothing.
//
// Built-in commands receive an `Args` (see commands.c3). Standalone
// plugins keep the frozen `fn void(void*, String)` handler signature for
// ABI stability, but can split their raw string the same way through the
// `args_split` PluginAPI helper (see plugin.c3 / server.c3).

module whisker::args;

// Maximum number of tokens a single command line can produce. AO commands
// never come close to this; anything beyond it is simply ignored so a
// hostile client can't make us scan an unbounded list.
const int MAX_ARGS = 32;

struct Args {
    String           raw;          // the full argument tail, untouched
    String[MAX_ARGS] tokens;       // parsed, quote-stripped tokens
    usz[MAX_ARGS]    starts;       // each token's start offset within raw
    int              count;        // number of tokens parsed
}

fn bool is_space(char ch) @local {
    return ch == ' ' || ch == '\t';
}

// Tokenize a raw argument string into an Args list.
//
// Quote handling: a token beginning with " or ' runs until the matching
// closing quote (or end of string) and is stored without the quotes. Bare
// tokens run until the next whitespace. This makes multi-word arguments
// like a ban reason or a "3 days" duration a single token.
fn Args parse(String raw) {
    Args a;
    a.raw = raw;
    a.count = 0;

    usz i = 0;
    while (i < raw.len && a.count < MAX_ARGS) {
        // Skip whitespace separating tokens.
        while (i < raw.len && is_space(raw[i])) i++;
        if (i >= raw.len) break;

        usz token_start = i;          // start in raw, used by rest()
        char first = raw[i];

        if (first == '"' || first == '\'') {
            // Quoted token — content runs to the matching quote.
            i++;                       // skip the opening quote
            usz content_start = i;
            while (i < raw.len && raw[i] != first) i++;
            usz content_end = i;       // exclusive
            if (i < raw.len) i++;      // consume the closing quote

            a.tokens[a.count] = content_start < content_end
                ? raw[content_start..content_end - 1]
                : "";
        } else {
            // Bare token — runs to the next whitespace.
            usz content_start = i;
            while (i < raw.len && !is_space(raw[i])) i++;
            a.tokens[a.count] = raw[content_start..i - 1];
        }

        a.starts[a.count] = token_start;
        a.count++;
    }

    return a;
}

// True when no arguments were supplied.
fn bool Args.is_empty(&self) {
    return self.count == 0;
}

// Token at index `i`, or "" if out of range.
fn String Args.get(&self, int i) {
    if (i < 0 || i >= self.count) return "";
    return self.tokens[i];
}

// Token at index `i`, or `fallback` if out of range.
fn String Args.opt(&self, int i, String fallback) {
    if (i < 0 || i >= self.count) return fallback;
    return self.tokens[i];
}

// Token at index `i` parsed as an int, or `fallback` if missing/invalid.
fn int Args.get_int(&self, int i, int fallback) {
    if (i < 0 || i >= self.count) return fallback;
    return self.tokens[i].to_int() ?? fallback;
}

// The untouched remainder of the raw line starting at token `from`.
// Useful for "everything after the first argument is free text" commands
// such as /pm <uid> <message>. Returns "" if `from` is out of range.
fn String Args.rest(&self, int from) {
    if (from < 0 || from >= self.count) return "";
    return self.raw[self.starts[from]..];
}

// True if `flag` appears as one of the tokens (e.g. a "-d" switch).
fn bool Args.has(&self, String flag) {
    for (int i = 0; i < self.count; i++) {
        if (self.tokens[i] == flag) return true;
    }
    return false;
}

// The token immediately following `flag`, or `fallback` if `flag` is
// absent or has no value after it (e.g. value_of("-d", "3d")).
fn String Args.value_of(&self, String flag, String fallback) {
    for (int i = 0; i < self.count - 1; i++) {
        if (self.tokens[i] == flag) return self.tokens[i + 1];
    }
    return fallback;
}
