%{
//Inspired by Zhenbang You
#define YYSTYPE void*

// shorthand for taking int value from a void*
#define V(p) (*((int*)(p)))     //将p强制转换成指向int的指针，然后得到这个int的值

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

    if(oldcid != nullptr){     //在变量表中已经出现过
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    auto cid = new IntIdentToken(name, true);  //const   新建一个节点
    cid->setVal(V($3));
    nowScope->addToken(cid);     //在当前的scope中增加一个节点
}
;

ConstInitVal: ConstExp
{
    auto cid = (IntIdentToken*)$1;
    if(!cid->isConst()){
        yyerror("Excepting constant expression.");
    }
    $$ = new int(cid->Val());
}
;

ConstExp: AddExp
;

AddExp: MulExp
    |  AddExp ADD MulExp
{
    auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
    if(*c1 && *c2){
        $$ = new IntIdentToken(c1->Val() + c2->Val());
    }
    else{
        auto newcid = new IntIdentToken();
        out << newcid->Declare() << endl;
        out << newcid->getName() << " = " << c1->getName() << " + " << c2->getName() << endl;
        $$ = newcid;
    }
}
    | AddExp SUB MulExp
{
    auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
    if(*c1 && *c2){
        $$ = new IntIdentToken(c1->Val() - c2->Val());
    }
    else{
        auto newcid = new IntIdentToken();
        out << newcid->Declare() << endl;
        out << newcid->getName() << " = " << c1->getName() << " - " << c2->getName() << endl;
        $$ = newcid;
    }
}
;

MulExp: UnaryExp
;

UnaryExp: PrimaryExp
;

PrimaryExp: NUMBER
{
    $$ = new IntIdentToken(V($1));
}
    |   LPAREN Exp RPAREN
{
    $$ = $2;
}
    |   LVal
{
    auto cid = (IntIdentToken*) $1;
    if(cid->isSlice()){         // 注意数组元素在右边不能直接用
        /*例如var T1=a[2] T2 = T1+2*/
        auto newcid = new IntIdentToken();
        out << newcid->getName() << " = " << cid->getName() << endl;
        cid = newcid; 
    }
    $$ = cid;
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

LVal: IDENT
{
    auto name = *(string*) $1;
    auto cid = (IdentToken*)nowScope->findAll(name);   // 用变量进行运算，只需要有一个域包含即可

    if(cid == nullptr){
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" undifined in this scope.";
        yyerror(errmsg);
    }

    if(cid->Type() != IntType){
        yyerror("Int identifier required.");
    }
    cid = (IntIdentToken*)cid;

    $$ = cid;
}
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