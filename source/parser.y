%{
//Inspired by Zhenbang You
#define YYSTYPE void*

// shorthand for taking int value from a void*
#define V(p) (*((int*)(p)))

// Common headers
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
using namespace std;

// Token class
#include "tokenclass.h"

// flex functions
void yyerror(const char *);
void yyerror(const string&);
extern int yylex();
extern int yyparse();
extern const int INTSIZE;

Scope globalScope;
Scope *nowScope = &globalScope;

auto arrOp_assign = ArrayOperator();
auto arrOp_access = ArrayOperator();

// Currently print to the screen. Will change to files.
ostream &out = cout;

FuncIdentToken *nowFunc = nullptr;

%}

%token ADD SUB MUL DIV MOD
%token IDENT
%token LPAREN RPAREN LCURLY RCURLY LBRAC RBRAC
%token INT CONST VOID
%token LE LEQ GE GEQ EQ NEQ AND OR NOT
%token IF ELSE WHILE BREAK CONT RETURN
%token ASSIGN
%token SEMI COMMA PERIOD
%token NUMBER

%%
CompUnit: Decl
    | CompUnit Decl
;

Decl: ConstDecl
    | VarDecl
;

ConstDecl: CONST INT ConstDefs SEMI
;

ConstDefs: ConstDef 
    |   ConstDefs ConstDef
;

ConstDef: IDENT ASSIGN ConstInitVal
{
    auto name = *(string*)$1;
    auto oldcid = nowScope->findOne(name);

    if(oldcid != nullptr){
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    auto cid = new IntIdentToken(name, true);  //const
    cid->setVal(V($3));
    nowScope->addToken(cid);
}
;

ConstInitVal: ConstExp
;

ConstExp: AddExp
;

AddExp: MulExp
;

MulExp: UnaryExp
;

UnaryExp: PrimaryExp
;

PrimaryExp: NUMBER
{
    $$ = new IntIdentToken(V($1));
}
;

VarDecl: INT VarDefs SEMI
;

VarDefs: VarDefs COMMA VarDef
    |   VarDef
;

VarDef: IDENT
{
    auto name = *(string*) $1;
    auto oldcid = nowScope->findOne(name);

    if(oldcid != nullptr){
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    auto cid = new IntIdentToken(name, false); //not const. Initially 0
    nowScope->addToken(cid);

    out << cid->Declare() << endl;
    out << cid->getName() << " = 0" << endl;
}
    |   IDENT ASSIGN InitVal
{
    auto name = *(string*) $1;
    auto oldcid = nowScope->findOne(name);
    auto initRes = (IntIdentToken*)$3;

    if(oldcid != nullptr){
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    IntIdentToken *cid;

    // cid = new IntIdentToken(name, false);
    // out << cid->Declare() << endl;
    // out << cid->getName() <<" = "<<initRes->getName()<<endl;

    if(!initRes->isTmp()){
        cid = new IntIdentToken(name, false);
        out << cid->Declare() << endl;
        out << cid->getName() <<" = "<<initRes->getName()<<endl;
    }
    else{
        cid = initRes;
        cid->setVarName(name);
        cid->setTmp(false);
    }
    nowScope->addToken(cid);
}
;

InitVal: Exp
{
    auto cid = (IdentToken*) $1;
    if(cid->Type() != IntType){
        yyerror("Interger initial value required.");
    }
    $$ = cid;
}
;

Exp: AddExp
;




%%

void yyerror(const char *s) {
    extern int yylineno, charNum;
    cout << "Line " << yylineno << "," << charNum << ": " << s << endl;
    exit(1);
}

void yyerror(const string &s) {
    yyerror(s.c_str());
}

int main() {
    ios::sync_with_stdio(false);
    yyparse();
    return 0;
}