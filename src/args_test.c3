// Whisker AO2 Server — Argument Parser Tests
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Unit tests for the quote-aware command argument tokenizer.
// Run with: c3c test
// These @test functions are excluded from normal `c3c build` output.

module whisker::args_test @test;

import whisker::args;

fn void empty_string() {
    args::Args a = args::parse("");
    assert(a.count == 0);
    assert(a.is_empty());
    assert(a.get(0) == "");
    assert(a.opt(0, "fallback") == "fallback");
    assert(a.get_int(0, -1) == -1);
}

fn void single_token() {
    args::Args a = args::parse("12");
    assert(a.count == 1);
    assert(a.get(0) == "12");
    assert(a.get_int(0, -1) == 12);
}

fn void bare_tokens() {
    args::Args a = args::parse("def pro wit");
    assert(a.count == 3);
    assert(a.get(0) == "def");
    assert(a.get(1) == "pro");
    assert(a.get(2) == "wit");
    assert(a.get(3) == "");
}

// The motivating example: /ban 12 "ban evading" "3 days"
fn void quoted_tokens() {
    args::Args a = args::parse(`12 "ban evading" "3 days"`);
    assert(a.count == 3);
    assert(a.get(0) == "12");
    assert(a.get(1) == "ban evading");
    assert(a.get(2) == "3 days");
    assert(a.get_int(0, -1) == 12);
}

fn void single_quotes() {
    args::Args a = args::parse(`5 'hello world'`);
    assert(a.count == 2);
    assert(a.get(1) == "hello world");
}

fn void empty_quoted_token() {
    args::Args a = args::parse(`5 "" tail`);
    assert(a.count == 3);
    assert(a.get(1) == "");
    assert(a.get(2) == "tail");
}

fn void rest_is_raw_remainder() {
    args::Args a = args::parse("5 hello world there");
    assert(a.get_int(0, -1) == 5);
    // Everything after the first token, untouched.
    assert(a.rest(1) == "hello world there");
    assert(a.rest(0) == "5 hello world there");
    assert(a.rest(99) == "");
}

fn void extra_whitespace_is_collapsed() {
    args::Args a = args::parse("  a    b  ");
    assert(a.count == 2);
    assert(a.get(0) == "a");
    assert(a.get(1) == "b");
}

fn void flag_helpers() {
    args::Args a = args::parse("12 -d 3d reason");
    assert(a.has("-d"));
    assert(!a.has("-x"));
    assert(a.value_of("-d", "1h") == "3d");
    assert(a.value_of("-x", "1h") == "1h");
}

fn void unterminated_quote_runs_to_end() {
    args::Args a = args::parse(`5 "no closing quote`);
    assert(a.count == 2);
    assert(a.get(1) == "no closing quote");
}
