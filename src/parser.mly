%{
open Types

let elaborate_schema foralls typ =
  let rec help typ =
    match typ with
    | TyVar _ -> typ
    | TyCon name -> if List.mem name foralls then TyVar name else typ
    | TyArr(args, ret) -> TyArr(List.map help args, help ret)
    | TyTup(args) -> TyTup(List.map help args)
  in (foralls, help typ)
;;

let make_program (statements, body) =
  {statements; body}

%}

%token <int> NUM
%token <string> ID STRING
%token LBRACK RBRACK DEF ADD1 SUB1 LPAREN RPAREN LET REC IN EQUAL COMMA PLUS MINUS TIMES IF COLON ELSECOLON ELSE TRUE FALSE ISBOOL ISNUM ISTUPLE LAMBDA EQEQ LESS GREATER PRINTSTACK EOF LESSEQ GREATEREQ AND OR NOT GETS BEGIN END SEMI ELLIPSIS ARROW INCLUDE DATA PIPE

%left LPAREN
%left PLUS MINUS TIMES GREATER LESS EQEQ LESSEQ GREATEREQ AND OR


%type <(Lexing.position * Lexing.position) Types.program> program

%start program

%%

const :
  | NUM { ENumber($1, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | TRUE { EBool(true, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | FALSE { EBool(false, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | ELLIPSIS { EEllipsis((Parsing.symbol_start_pos(), Parsing.symbol_end_pos ())) }
  | STRING { EString($1, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }

prim1 :
  | ADD1 { Add1 }
  | SUB1 { Sub1 }
  | NOT { Not }
  | ISBOOL { IsBool }
  | ISNUM { IsNum }
  | ISTUPLE { IsTuple }
  | PRINTSTACK { PrintStack }

binds :
  | ID tyann EQUAL expr { [LetBind($1, $2, $4, (Parsing.rhs_start_pos 1, Parsing.rhs_end_pos 1))] }
  | ID tyann EQUAL expr COMMA binds { LetBind($1, $2, $4, (Parsing.rhs_start_pos 1, Parsing.rhs_end_pos 1))::$6 }
  | LPAREN ids RPAREN tyann EQUAL expr { [TupDestr($2, $4, $6, (Parsing.rhs_start_pos 1, Parsing.rhs_end_pos 1))] }
  | LPAREN ids RPAREN tyann EQUAL expr COMMA binds { TupDestr($2, $4, $6, (Parsing.rhs_start_pos 1, Parsing.rhs_end_pos 1))::$8 }

tyann :
  | { None }
  | COLON schema { Some $2 }

schema :
  | LBRACK ids RBRACK typ { elaborate_schema (List.map fst $2) $4 }
  | typ { elaborate_schema [] $1 }

typ :
  | ID { TyCon $1 }
  | LPAREN typ typs ARROW typ RPAREN { TyArr($2::$3, $5) }
  | LPAREN typ typs RPAREN { TyTup ($2::$3) }


typs :
  | { [] }
  | COMMA typ typs { $2 :: $3 }

typ_id :
  | ID { TyVar $1 }

typ_ids :
  | { [] }
  | typ_id { [$1] }
  | typ_id COMMA typ_ids { $1::$3 }

ids :
  | ID { [$1, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())] }
  | ID COMMA ids { ($1, (Parsing.rhs_start_pos 1, Parsing.rhs_end_pos 1))::$3 }

exprs :
  | expr { [$1] }
  | expr COMMA exprs { $1::$3 }

tuple_exprs :
  | expr COMMA { [$1] }
  | expr COMMA exprs { $1::$3 }


colon_num:
  | COLON NUM COLON { $2 }

simple_expr :
  | prim1 LPAREN expr RPAREN { EPrim1($1, $3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LPAREN tuple_exprs RPAREN { ETuple($2, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LPAREN expr RPAREN { $2 }
  | simple_expr LPAREN exprs RPAREN { EApp($1, $3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr LPAREN RPAREN { EApp($1, [], (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LPAREN LAMBDA ids COLON expr RPAREN { ELambda($3, $5, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LPAREN LAMBDA COLON expr RPAREN { ELambda([], $4, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr LBRACK expr RBRACK { EGetItem($1, $3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr LBRACK expr RBRACK GETS expr { ESetItem($1, $3, $6, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr LBRACK colon_num RBRACK { EGetItemExact($1, $3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr LBRACK colon_num RBRACK GETS expr { ESetItemExact($1, $3, $6, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | BEGIN block_exprs END { ESeq($2, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | const { $1 }
  | ID { EId($1, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }

data_branch :
  | ID LPAREN typ typs RPAREN { DDataConstructor($1, $3::$4, (Parsing.symbol_start_pos(), Parsing.symbol_end_pos())) }
  | ID { DDataSingleton($1, (Parsing.symbol_start_pos(), Parsing.symbol_end_pos())) }

rest_data_branches :
  | PIPE data_branch { [$2] }
  | PIPE data_branch data_branches { $2::$3 }

data_branches :
  | data_branch { [$1] }
  | data_branch rest_data_branches { $1::$2 }
  | rest_data_branches { $1 }

id_seq :
  | ID { [TyVar $1] }
  | ID id_seq { (TyVar $1)::$2 }

data_decl :
  | DATA ID EQUAL data_branches { SDataDecl($2, [], $4, (Parsing.symbol_start_pos(), Parsing.symbol_end_pos()))  }
  | DATA id_seq ID EQUAL data_branches { SDataDecl($3, $2, $5, (Parsing.symbol_start_pos(), Parsing.symbol_end_pos())) }

block_exprs :
  | expr { [$1] }
  | expr SEMI { [$1] }
  | expr SEMI block_exprs { $1::$3 }

binop:
  | PLUS { Plus }
  | MINUS { Minus }
  | TIMES { Times }
  | EQEQ { Eq }
  | LESS { Less }
  | GREATER { Greater }
  | LESSEQ { LessEq }
  | GREATEREQ { GreaterEq }
  | AND { And }
  | OR { Or }

binop_expr :
  | binop_expr binop binop_expr { EPrim2($2, $1, $3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | simple_expr { $1 }

cond_expr:
  | IF expr COLON expr ELSECOLON expr { EIf($2, $4, $6, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | IF expr COLON expr ELSE cond_expr { EIf($2, $4, $6, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }

expr :
  | INCLUDE ID IN expr { EInclude($2, $4, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LET binds IN expr { ELet($2, $4, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LET REC binds IN expr { ELetRec($3, $5, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | cond_expr { $1 }
  | binop_expr { $1 }

top_level_stmt :
  | INCLUDE ID { SInclude($2, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LET binds { SLet($2, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | LET REC binds { SLetRec($3, (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())) }
  | data_decl { $1 }

top_level_stmts :
  | top_level_stmt SEMI { [$1] }
  | top_level_stmt SEMI top_level_stmts { $1::$3 }

program :
  | top_level_stmts EOF { make_program ($1, ENull) }
  | expr EOF { make_program ([], $1) }
  | top_level_stmt EOF { make_program ([$1], ENull) }
  | top_level_stmts expr EOF { make_program ($1, $2) }

%%
