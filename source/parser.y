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

Scope globalScope;      //建立初始的Scope节点
Scope *nowScope = &globalScope;

auto arrOp_assign = ArrayOperator();
auto arrOp_access = ArrayOperator();

// Currently print to the screen. Will change to files.
ostream &out = cout;         //用于输出

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
    |   ConstDefs COMMA ConstDef
;

ConstDef: IDENT ASSIGN ConstInitVal
{
    //out << "ConstDef IDENT ASSIGN ConstInitVal = " << V($3) <<endl;
    auto name = *(string*)$1;        //得到变量名
    auto oldcid = nowScope->findOne(name);         //查找变量在当前域中是否出现过

    if(oldcid != nullptr){     //在变量表中已经出现过
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    auto cid = new IntIdentToken(name, true);  //const   新建一个INT节点
    cid->setVal(V($3));              //当前INT节点的值为$3
    nowScope->addToken(cid);     //在当前的scope中增加一个节点，得到当前节点的scope
}
    |   IDENT ArrayDim 
{          /* 例如a[2][3] = {1,2,3,4,5,6}  */
    auto name = *(string*)$1;
    auto oldcid = nowScope->findOne(name);

    if(oldcid != nullptr){
        string errmsg = "\"";
        errmsg += name;
        errmsg += "\" already defined in this scope.";
        yyerror(errmsg);
    }

    auto cid = new ArrayIdentToken(name, true);    //const型变量
    cid->setShape(*(deque<int>*)$2);
    nowScope->addToken(cid);

    out << cid->Declare()<<endl;     //输出数组变量声明部分

    arrOp_assign.setTarget(cid);      //用于操作数组，把目标对象设置为当前的cid
}
    ASSIGN ConstArrayVal
{
    string &arrName = arrOp_assign.name();
    int n = arrOp_assign.size();
    for(int i = 0;i<n;i++){
        out <<arrName<<"["<<i*INTSIZE<<"] = "<<arrOp_assign[i]<<endl;
    }
}
;

ArrayDim: ArrayDim LBRAC ConstExp RBRAC
{   
    /*以[2][3][4]为例，deque的内容依次为2，3，4*/
    $$ = $1;
    ((deque<int>*)$$)->push_back(V($3));
}
    | LBRAC ConstExp RBRAC
{
    $$ = new deque<int>;
    ((deque<int>*)$$)->push_back(V($2));
}
;

ConstArrayVal: ConstExp
{
    if(!arrOp_assign.addOne(V($1))){
        yyerror("Array out of bound.");
    }
}
    |   LCURLY RCURLY
{
    if(!arrOp_assign.jumpOne()){            // a[3][2] = {1,2,{},3,4}，直接跳过这一层，都赋成0
        yyerror("Nested list too deep.");
    }
}
    | LCURLY
{
    if(!arrOp_assign.moveDown()){             // a[2][2] = {1,2,{3,4}},遇到左括号往下移一层
        yyerror("Nested list too deep.");
    }
}
    ConstArrayVals RCURLY
{
    if(!arrOp_assign.moveUp()){                 //遇到右括号向上移一层
        yyerror("Unknown error in \"}\"");
    }
}
;

ConstArrayVals: ConstArrayVals COMMA ConstArrayVal
    |   ConstArrayVal
;

ConstInitVal: ConstExp
;

ConstExp: AddExp
{
    auto cid = (IntIdentToken*)$1;
    if (!cid->isConst()) {
        yyerror("Expecting constant expression.");
    }
    $$ = new int(cid->Val());
}
;

AddExp: MulExp
    |  AddExp ADD MulExp
{
    auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
    if(*c1 && *c2){
        $$ = new IntIdentToken(c1->Val() + c2->Val());    //此时可以直接得到结果
    }
    else{
        auto newcid = new IntIdentToken();    //生成临时变量
        out << newcid->Declare() << endl;
        out << newcid->getName() << " = " << c1->getName() << " + " << c2->getName() << endl;
        $$ = newcid;      //得到中间结果
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
    |   MulExp MUL UnaryExp
{
    auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
    if(*c1 && *c2){
        $$ = new IntIdentToken(c1->Val() * c2->Val());
    }
    else{
        auto newcid = new IntIdentToken();      //临时变量
        out << newcid->Declare() << endl;
        out << newcid->getName() << " = " << c1->getName() << " * " << c2->getName() << endl;
        $$ = newcid;
    }
}
    |   MulExp DIV UnaryExp
{
    auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
    if(*c1 && *c2){
        if (c2->Val() == 0){
            yyerror("devided by zero!");
        }
        $$ = new IntIdentToken(c1->Val() / c2->Val());
    }
    else{
        auto newcid = new IntIdentToken();      //临时变量
        out << newcid->Declare() << endl;
        out << newcid->getName() << " = " << c1->getName() << " * " << c2->getName() << endl;
        $$ = newcid;
    }
}
    |   MulExp MOD UnaryExp
    {
        auto c1 = (IntIdentToken*)$1, c2 = (IntIdentToken*)$3;
        if(*c1 && *c2){
            $$ = new IntIdentToken(c1->Val() % c2->Val());
        }
        else{
            auto newcid = new IntIdentToken();      //临时变量
            out << newcid->Declare() << endl;
            out << newcid->getName() << " = " << c1->getName() << " % " << c2->getName() << endl;
            $$ = newcid;
        }
    }
;

UnaryExp: PrimaryExp
;

PrimaryExp: NUMBER
{
    $$ = new IntIdentToken(V($1));     //生成一个Int型Token
    //out <<"NUMBER = " << V($1) <<endl;
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

    out << cid->Declare() << endl;       // 输出声明语句
    out << cid->getName() << " = 0" << endl;      // 变量初始化为0
}
    |   IDENT ASSIGN InitVal
{
    auto name = *(string*) $1;
    auto oldcid = nowScope->findOne(name);
    auto initRes = (IntIdentToken*)$3;      //结果

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