%{

using namespace std;

BooleanDAGCreator* currentBD;
stack<string> namestack;
vartype Gvartype;

bool_node *comparisson (bool_node *p1, bool_node *p2, bool_node::Type atype)
{
    Assert (p1 || p2, "Can't have both comparisson's children NULL");   
    return currentBD->new_node(p1, p2, atype);     
}




#ifdef CONST
#undef CONST
#endif


#define YYLEX_PARAM yyscanner
#define YYPARSE_PARAM yyscanner
#define YY_DECL int yylex (YYSTYPE* yylval, yyscan_t yyscanner)
extern int yylex (YYSTYPE* yylval, yyscan_t yyscanner);

%}

%pure_parser

%union {
	int intConst;
	bool boolConst;
	std::string* strConst;
	double doubleConst;		
	std::list<int>* iList;
	list<bool_node*>* nList;
	list<string*>* sList;
	vartype variableType;
	BooleanDAG* bdag;
	bool_node* bnode;
}

%token <doubleConst> T_dbl
%token<intConst>  T_int
%token<intConst>  T_bool
%token<strConst> T_ident               
%token<strConst> T_OutIdent
%token<strConst> T_NativeCode
%token<strConst> T_string
%token<boolConst> T_true
%token<boolConst> T_false
%token<variableType> T_vartype
%token T_twoS
%token T_ppls
%token T_mmns
%token T_eq
%token T_neq
%token T_and
%token T_or
%token T_For
%token T_ge
%token T_le


%token T_Native
%token T_NativeMethod
%token T_Sketches
%token T_new
%token T_add
%token T_Init


%token T_def
%token T_assert

%token T_eof

%type<intConst> Program
%type<strConst> Ident
%type<intConst> WorkStatement
%type<bnode> Expression
%type<bnode> Term
%type<intConst> NegConstant
%type<intConst> Constant
%type<intConst> ConstantExpr
%type<intConst> ConstantTerm
%type<nList> varList
%type<sList> IdentList
%type<sList> TokenList
%type<bdag> AssertionExpr



%left '+'
%left '*'
%left '/'
%left '%'
%left '<'
%left '>'
%left T_eq
%left T_neq
%right '?'
%right ':'


%%

Program: MethodList T_eof{  $$=0; return 0;}


MethodList: {}
| Method MethodList {}
| HLAssertion MethodList {}


InList: T_ident {  

    if( Gvartype == INT){

		currentBD->create_inputs( 2 /*NINPUTS*/ , *$1); 
	}else{

		currentBD->create_inputs(-1, *$1); 
	}	

}
| T_ident {
	
    if( Gvartype == INT){

		currentBD->create_inputs( 2 /*NINPUTS*/ , *$1); 
	}else{

		currentBD->create_inputs(-1, *$1); 
	}	
} InList

OutList: T_ident { 	 currentBD->create_outputs(-1, *$1); }
| T_ident OutList{
	
	currentBD->create_outputs(-1, *$1);
}


ParamDecl: T_vartype T_ident {  
	if( $1 == INT){

		currentBD->create_inputs( 2 /*NINPUTS*/ , *$2); 
	}else{

		currentBD->create_inputs(-1, *$2); 
	}	
}
| '!' T_vartype T_ident {
 	 if( $2 == INT){

		 currentBD->create_outputs(2 /* NINPUTS */, *$3);
 	 }else{

	 	 currentBD->create_outputs(-1, *$3); 
 	 }
 }
| T_vartype {
Gvartype = $1;

 } '[' ConstantExpr ']' InList 
| '!' T_vartype '[' ConstantExpr ']' OutList 


ParamList: /*empty*/ 
| ParamDecl
| ParamDecl ',' ParamList 


Method: T_def T_ident
{		modelBuilding.restart ();
		if(currentBD!= NULL){
			delete currentBD;
		}
		currentBD = envt->newFunction(*$2);
		delete $2;
}
'(' ParamList ')' '{' WorkBody '}' { 
	currentBD->finalize();
	modelBuilding.stop();
}



AssertionExpr: T_ident T_Sketches T_ident 
{
	$$ = envt->prepareMiter(envt->getCopy(*$3),  envt->getCopy(*$1));
}

HLAssertion: T_assert {solution.restart();} AssertionExpr ';'
{
	int tt = envt->assertDAG($3, std::cout);
	envt->printControls("");
	solution.stop();
	cout<<"COMPLETED"<<endl;
	if(tt != 0){
		return tt;
	}
}
| T_ident '(' TokenList ')' ';'
{
	int tt = envt->runCommand(*$1, *$3);
	delete $1;
	delete $3;
	if(tt >= 0){
		return tt;
	}
}

TokenList:  {
	$$ = new list<string*>();	
}
| T_ident TokenList{
	$$ = $2;
	$$->push_back( $1);
}
| T_string TokenList{
	$$ = $2;
	$$->push_back( $1);
}


WorkBody:  { /* Empty */ }
| WorkBody WorkStatement { /* */ }


WorkStatement:  ';' {  $$=0;  /* */ }
| T_ident '=' Expression ';' {
	currentBD->alias( *$1, $3);
	delete $1;
}							  
| '$' IdentList T_twoS varList '$''[' Expression ']' '=' Expression ';' {

	list<string*>* childs = $2;
	list<string*>::reverse_iterator it = childs->rbegin();
	
	list<bool_node*>* oldchilds = $4;
	list<bool_node*>::reverse_iterator oldit = oldchilds->rbegin();
	
	bool_node* rhs;
	rhs = $10;
	int bigN = childs->size();
	Assert( bigN == oldchilds->size(), "This can't happen");	

	for(int i=0; i<bigN; ++i, ++it, ++oldit){		
		ARRASS_node* an = dynamic_cast<ARRASS_node*>(newArithNode(arith_node::ARRASS));
		an->multi_mother.reserve(2);
		an->multi_mother.push_back(*oldit);			
		an->multi_mother.push_back(rhs);
		Assert( rhs != NULL, "AAARRRGH This shouldn't happen !!");
		Assert($7 != NULL, "1: THIS CAN'T HAPPEN!!");
		an->quant = i;		
		currentBD->alias( *(*it), currentBD->new_node($7,  NULL,  an) );
		delete *it;
	}
	delete childs;
	delete oldchilds;	
}

| T_OutIdent '=' Expression ';' {
	Assert(false, "UNREACHABLE");
	currentBD->create_outputs(2 /*NINPUTS*/, $3, *$1);
	delete $1;
}
| T_assert Expression ';' {
  if ($2) {
    /* Asserting an expression, construct assert node. */
    
    currentBD->new_node ($2, NULL, bool_node::ASSERT);
  }
} 
| T_assert Expression ':' T_string ';' {
  if ($2) {
    /* Asserting an expression, construct assert node. */
	if(!($2->type == bool_node::CONST && dynamic_cast<CONST_node*>($2)->getVal() == 1)){
		ASSERT_node* bn = dynamic_cast<ASSERT_node*>(newBoolNode(bool_node::ASSERT));
		bn->setMsg(*$4);
		currentBD->new_node ($2, NULL, bn);
	}    
    delete $4;
  }
} 


Expression: Term { $$ = $1; }
| Term '&' Term {
	$$ = currentBD->new_node($1,  $3, bool_node::AND);	
}
| Term T_and Term{
	$$ = currentBD->new_node($1,  $3, bool_node::AND);
}
| Term '|' Term {
	$$ = currentBD->new_node($1,  $3, bool_node::OR);	
}
| Term T_or Term { 	
	$$ = currentBD->new_node($1,  $3, bool_node::OR);	
}
| Term '^' Term{	
	$$ = currentBD->new_node($1,  $3, bool_node::XOR);	
}
| Term T_neq Term{	
	bool_node* tmp = currentBD->new_node($1,  $3, bool_node::EQ);
	$$ = currentBD->new_node (tmp, NULL, bool_node::NOT);	
}
| Term T_eq Term { 			
	$$ = currentBD->new_node($1,  $3, bool_node::EQ);
}
| '$' varList '$' '[' Expression ']' {
	int pushval = 0;
	arith_node* an = newArithNode(arith_node::ARRACC);
	list<bool_node*>* childs = $2;
	list<bool_node*>::reverse_iterator it = childs->rbegin();
	int bigN = childs->size();
	an->multi_mother.reserve(bigN);
	for(int i=0; i<bigN; ++i, ++it){
		an->multi_mother.push_back(*it);
	}		
	Assert($5 != NULL, "2: THIS CAN'T HAPPEN!!");	
	$$ = currentBD->new_node($5, NULL,  an);
	delete childs;	
}

| T_twoS varList T_twoS {
	arith_node* an = newArithNode(arith_node::ACTRL);
	list<bool_node*>* childs = $2;
	list<bool_node*>::reverse_iterator it = childs->rbegin();
	int bigN = childs->size();
	an->multi_mother.reserve(bigN);
	for(int i=0; i<bigN; ++i, ++it){
		an->multi_mother.push_back(*it);
	}		
	$$ = currentBD->new_node(NULL, NULL, an); 
	delete childs;
}

| Term '+' Term {
	$$ = currentBD->new_node($1,  $3, bool_node::PLUS); 	
}

| Term '/' Term {	
	$$ = currentBD->new_node($1,  $3, bool_node::DIV); 	
}

| Term '%' Term {	
	$$ = currentBD->new_node($1,  $3, bool_node::MOD); 	
}

| Term '*' Term {
	$$= currentBD->new_node($1,  $3, bool_node::TIMES);
}
| Term '-' Term {
	bool_node* neg1 = currentBD->new_node($3, NULL, bool_node::NEG);
	$$ = currentBD->new_node($1, neg1, bool_node::PLUS); 	
}
| Term '>' Term {
	$$ = comparisson($1, $3, bool_node::GT);
}
| Term '<' Term {
	$$ = comparisson($1, $3, bool_node::LT);
}
| Term T_ge Term {
	$$ = comparisson($1, $3, bool_node::GE);
}
| Term T_le Term {
	$$ = comparisson($1, $3, bool_node::LE);
}
| Expression '?' Expression ':' Expression {
	arith_node* an = newArithNode(arith_node::ARRACC);
	bool_node* yesChild =($3);
	bool_node* noChild = ($5);
	an->multi_mother.push_back( noChild );
	an->multi_mother.push_back( yesChild );	
	$$ = currentBD->new_node($1, NULL, an); 	
} 



varList: { /* Empty */  	$$ = new list<bool_node*>();	}
| Term varList{
//The signs are already in the stack by default. All I have to do is not remove them.
	if($1 != NULL){
		$2->push_back( $1 );
	}else{
		$2->push_back( NULL );
	}
	$$ = $2;
}

IdentList: T_ident {
	$$ = new list<string*>();	
	$$->push_back( $1);
}
| T_ident IdentList{
	$$ = $2;
	$$->push_back( $1);
}

Term: Constant {
	$$ = currentBD->create_const($1);
}	 

| T_ident '[' T_vartype ']' '(' varList  ')''(' Expression ')' '[' T_ident ',' Constant ']' {
	
	list<bool_node*>* params = $6;
	if(false && params->size() == 0){
		if( $3 == INT){
			$$ = currentBD->create_inputs( 2 /*NINPUTS*/ , *$1); 
		}else{
			$$ = currentBD->create_inputs(-1, *$1);
		}
		delete $1;
	}else{	
		string& fname = *$1;
		list<bool_node*>::reverse_iterator parit = params->rbegin();
		UFUN_node* ufun = new UFUN_node(fname);
		ufun->outname = *$12;
		int fgid = $14;
		ufun->fgid = fgid;		
		if(currentBD->methdparams.count(fgid)>0){
			ufun->multi_mother = currentBD->methdparams[fgid];
		}else{
			for( ; parit != params->rend(); ++parit){
				ufun->multi_mother.push_back((*parit));
			}
		}
		
		if( $3 == INT){
			ufun->set_nbits( 2 /*NINPUTS*/  );
		}else{
	
			ufun->set_nbits( 1  );
		}

		ufun->name = (currentBD->new_name(fname));
		$$ = currentBD->new_node($9, NULL, ufun);

		if(currentBD->methdparams.count(fgid)==0){
			currentBD->methdparams[fgid].push_back($$);
		}		
		
		
		
		delete $1;
		delete $12;
	}
	delete $6;
}

| '-' Term {	
	if($2->type == bool_node::CONST){
		$$ = currentBD->create_const(-dynamic_cast<CONST_node*>($2)->getVal());
	}else{
		$$ = currentBD->new_node($2, NULL, bool_node::NEG);		
	}	
}
| '!' Term { 
	$$ = currentBD->new_node($2, NULL, bool_node::NOT);		    
}

| '(' Expression ')' { 
						$$ = $2; 
						}
| Ident { 			
			$$ = currentBD->get_node(*$1);
			delete $1;				
			 
		}
| '<' Ident '>' {		
	$$ = currentBD->create_controls(-1, *$2);
	delete $2;
}
| '<' Ident Constant '>' {
	int nctrls = $3;
	if(overrideNCtrls){
		nctrls = NCTRLS;
	}
	$$ = currentBD->create_controls(nctrls, *$2);
	delete $2;
}
| '<' Ident Constant '*' '>' {
	$$ = currentBD->create_controls($3, *$2);
	delete $2;

}


ConstantExpr: ConstantTerm { $$ = $1; }
| ConstantExpr '+' ConstantTerm { $$ = $1 + $3; }
| ConstantExpr '-' ConstantTerm { $$ = $1 - $3; }

ConstantTerm: NegConstant { $$ = $1; }
| '(' ConstantTerm ')' { $$ = $2; }
| ConstantTerm '*' ConstantTerm { $$ = $1 * $3; } 
| ConstantTerm '/' ConstantTerm { Assert( $3 != 0, "You are attempting to divide by zero !!");
							      $$ = $1 / $3; } 
| ConstantTerm '%' ConstantTerm { Assert( $3 != 0, "You are attempting to mod by zero !!");
							      $$ = $1 % $3; }


NegConstant: Constant {  $$ = $1; }
| '-' Constant {  $$ = -$2; }

Constant: 
 T_int {  $$ = $1; }
| T_true { $$ = 1; }
| T_false { $$ = 0; }

Ident: T_ident { $$=$1; }

%%


void Inityyparse(){

	 	
}

void yyerror(char* c){
	Assert(false, c); 
}


int isatty(int i){



return 1;
}
