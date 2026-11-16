open Constrexpr

module Ser = Serlib.Ser_constrexpr

let check compare hash sexp_of of_sexp to_yojson of_yojson value =
  let check_copy copy =
    assert (compare value copy = 0);
    assert (hash value = hash copy)
  in
  check_copy (of_sexp (sexp_of value));
  match of_yojson (to_yojson value) with
  | Ok copy -> check_copy copy
  | Error message -> failwith message

let () =
  let qid = Libnames.qualid_of_ident (Names.Id.of_string "arg") in
  let term = CAst.make (CRef (qid, None)) in
  let pattern = CAst.make (CPatAtom (Some qid)) in
  let binders = [pattern, Glob_term.MaxImplicit] in
  let args = [term], [[term; term]], binders, [[CLocalPattern pattern]] in
  let pattern_args = [pattern], [[pattern; pattern]], binders in
  let custom_entry =
    Names.KerName.make (Names.ModPath.MPfile Names.DirPath.empty)
      (Names.Id.of_string "test")
  in
  List.iter
    (fun notation ->
      let expr = CAst.make (CNotation (None, notation, args)) in
      check Ser.compare_constr_expr Ser.hash_constr_expr Ser.sexp_of_constr_expr
        Ser.constr_expr_of_sexp Ser.constr_expr_to_yojson
        Ser.constr_expr_of_yojson expr;
      let expr =
        CAst.make (CPatNotation (None, notation, pattern_args, [pattern]))
      in
      check Ser.compare_cases_pattern_notation_substitution
        Ser.hash_cases_pattern_notation_substitution
        Ser.sexp_of_cases_pattern_notation_substitution
        Ser.cases_pattern_notation_substitution_of_sexp
        Ser.cases_pattern_notation_substitution_to_yojson
        Ser.cases_pattern_notation_substitution_of_yojson
        ([expr], [[expr; pattern]], binders))
    [InConstrEntry, "_ + _"; InCustomEntry custom_entry, "_ + _"]
