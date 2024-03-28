%{
#include "FunctionStruct.hpp"
#include <iostream>
#include <fstream>
#include <cstring>
#include <vector>
#include <utility>
#include <string>
#include <cmath>  
#include <map>
#include "parser1.hpp"


extern int yylex();
extern int yylineno;
extern char* yytext;
void yyerror(const char *s) {
    std::cerr << "Error at line " << yylineno << ": " << s << std::endl;
}


class VariableInfo {
public:
    std::string type;
    double numericValue;  // Pentru valori numerice (int, float)
    std::string textValue; // Pentru valori non-numerice (string, char)
    double numericArray[100];
    std::string textArray[100];
    int arraySize=0; 

    // Constructor implicit
    VariableInfo() : type(""), numericValue(0.0), textValue(""), arraySize(0) {}

    // Constructor pentru valori numerice
    VariableInfo(const std::string& type, double val) 
        : type(type), numericValue(val), textValue(""), arraySize(0) {}

    // Constructor pentru valori non-numerice
    VariableInfo(const std::string& type, const std::string& val) 
        : type(type), numericValue(0.0), textValue(val), arraySize(0) {}

    // Constructor pentru array-uri
    VariableInfo(const std::string& type, int size, bool isNumeric)
        : type(type), numericValue(0.0), textValue(""), arraySize(size) {
            if (isNumeric) {
                std::fill(std::begin(numericArray), std::end(numericArray), 0.0);
            }
            else {                 std::fill(std::begin(textArray), std::end(textArray), "");
        }
        }
};


// VARIABLE AND FUNCTION TABLE
std::map<std::string, VariableInfo> symbolTable;
std::map<std::string, Function> functionMap;

Function* currentFunction = nullptr;
void displayFunctions() {
    for (const auto& pair : functionMap) {
        const Function& func = pair.second;
        std::cout << "Function Name: " << func.name << std::endl;
        std::cout << "Return Type: " << func.returnType << std::endl;

        if (func.parameterCounter > 0) {
            std::cout << "Parameters: ";
            for (int i = 0; i < func.parameterCounter; ++i) {
                std::cout << func.parameterTypes[i] << " " << func.parameterNames[i];
                if (i < func.parameterCounter - 1) {
                    std::cout << ", ";
                }
            }
        } else {
            std::cout << "No parameters";
        }
        std::cout << std::endl << std::endl;
    }
}

std::vector<std::pair<std::string, std::string>> tempParameters;
std::vector<std::string> tempArgumentTypes;

bool validateFunctionCall(const std::string& functionName) {
    // Find the function in the function map
    auto funcIt = functionMap.find(functionName);
    if (funcIt == functionMap.end()) {
        std::cerr << "Function not declared: " << functionName << std::endl;
        return false;
    }

    // Retrieve the function object
    const Function& func = funcIt->second;

    // Check if the number of arguments matches
    if (tempArgumentTypes.size() != func.parameterCounter) {
        std::cerr << "Incorrect number of arguments for function: " << functionName << std::endl;
        return false;
    }

    // Compare each argument type with the corresponding formal parameter type
    for (size_t i = 0; i < tempArgumentTypes.size(); ++i) {
        if (tempArgumentTypes[i] != func.parameterTypes[i]) {
            std::cerr << "Type mismatch for parameter " << i + 1 << " in function call: " << functionName << std::endl;
            return false;
        }
    }

    // If everything is fine
    return true;
}




%}

%union {
    char* string;
  double value;    
  int index;
  Function* func;  // Pointer la structura Function
}

%token <string> TYPE ID STRING_LITERAL BOOL_LITERAL CHAR_LITERAL LEFT_BRACKET RIGHT_BRACKET 
%token<value> NR_F
%token<index> NR_INT
%token ASSIGN FUNCTION
%token '<' '>' EQ NEQ LEQ GEQ AND OR NEG
%left '-' '+'
%left '*' '/'
%left NEG     /* negation--unary minus */
%type<value> exp NR
%type <value> bool_statement
%type <func> function_declaration parameter parameter_list



%%
program:
/* empty */
    |program declarations
    | program function_declaration
    ;
    
function_declaration:
    FUNCTION TYPE ID '(' parameter_list ')' ';' {
        if (functionMap.find($3) != functionMap.end() || symbolTable.find($3) != symbolTable.end()) {
            std::cerr << "Error: Function name already used: " << $3 << std::endl;
        } else {
            // Create and add function to the map
            Function newFunction($2, $3);
            for (const auto& param : tempParameters) {
                newFunction.addParameter(param.first, param.second);
            }
            functionMap[$3] = std::move(newFunction);
            
            tempParameters.clear();
        }
    }
    ;


parameter_list:
     parameter_list ',' parameter
    | parameter
    ;

parameter:
    TYPE ID {
        for (const auto& param : tempParameters) {
            if (param.second == $2) {
                std::cerr << "Error: Duplicate parameter name: " << $2 << std::endl;
                return 1;
            }
        }
        tempParameters.emplace_back($1, $2);
    }
    |
    TYPE ID '[' ']' {
        std::string arrayType = std::string($1) + "[]";
        for (const auto& param : tempParameters) {
            if (param.second == $2) {
                std::cerr << "Error: Duplicate parameter name: " << $2 << std::endl;
                return 1;
            }
        }
        tempParameters.emplace_back(arrayType, $2);
    }
    ;


declarations:
    /* empty */
    | declarations declaration
    | declarations function_call
    ;

declaration:
TYPE ID ';' {
    if (symbolTable.find($2) == symbolTable.end()) {
        // Variable does not exist, add it to the symbol table
        if ($1 == "int" || $1 == "float") {
            symbolTable[$2] = VariableInfo($1, 0.0); // Initializare pentru numeric value
        } else {
            symbolTable[$2] = VariableInfo($1, ""); //  Initializare pentru text value
        }
    } else {
        // Variable already declared
        std::string error = "Variable already declared: " + std::string($2);
        yyerror(error.c_str());
    }
}
| TYPE ID '[' NR ']' ';' {
    if (symbolTable.find($2) == symbolTable.end()) {
        int size = (int)$4; 
        if (size > 0 && size <= 100) {
            bool isNumeric = ($1 == "int" || $1 == "float");
            symbolTable[$2] = VariableInfo($1, size, isNumeric);
        } else {
            std::string error = "Invalid array size (max integer 100): " + std::string($2);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Array already declared: " + std::string($2);
        yyerror(error.c_str());
    }
}



    
 
    | ID ASSIGN STRING_LITERAL ';' {
        auto it = symbolTable.find($1);
        if (it != symbolTable.end() && it->second.type == "string") {
            // Assign the string literal to the variable
            it->second.textValue = $3;
        } else {
            std::string error = "Variable not found or type mismatch: " + std::string($1);
            yyerror(error.c_str());
        }
    }
    
   | ID ASSIGN BOOL_LITERAL ';' {
        auto it = symbolTable.find($1);
        if (it != symbolTable.end() && it->second.type == "bool") {
            // Convert the string to a boolean and assign it
            bool value = std::string($3) == "true";
            it->second.textValue = value;
        } else {
            std::string error = "Variable not found or type mismatch for boolean assignment: " + std::string($1);
            yyerror(error.c_str());
        }
    }
    
    | ID ASSIGN CHAR_LITERAL ';' {
    auto it = symbolTable.find($1);
    if (it != symbolTable.end() && it->second.type == "char") {
        if (strlen($3) == 3) { // Check for correct format: 'x'
            {it->second.textValue = $3[1]; // Assign the char (second character in the string)
                printf("Char literal assignment: %s = %s\n", $1, $3);
}
        } else {
            std::string error = "Invalid char literal: " + std::string($3);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not found or type mismatch for char assignment: " + std::string($1);
        yyerror(error.c_str());
    }
}
   | ID ASSIGN ID ';' {
        auto lhs_it = symbolTable.find($1);
        auto rhs_it = symbolTable.find($3);
        if (lhs_it != symbolTable.end() && rhs_it != symbolTable.end()) {
            // Check if the types of both identifiers are compatible
            if (lhs_it->second.type == rhs_it->second.type) {
                // Perform the assignment
                lhs_it->second.textValue = rhs_it->second.textValue;
                                lhs_it->second.numericValue = rhs_it->second.numericValue;
            } else {
                std::string error = "Type mismatch in assignment between " + std::string($1) + " and " + std::string($3);
                yyerror(error.c_str());
            }
        } else {
            if (lhs_it == symbolTable.end()) {
                std::string error = "Variable not declared: " + std::string($1);
                yyerror(error.c_str());
            }
            if (rhs_it == symbolTable.end()) {
                std::string error = "Variable not declared: " + std::string($3);
                yyerror(error.c_str());
            }
        }
    }
| ID ASSIGN ID '[' NR ']' ';' {
    auto lhs_it = symbolTable.find($1);
    auto rhs_it = symbolTable.find($3);
    if (lhs_it != symbolTable.end() && rhs_it != symbolTable.end()) {
        int index = (int)$5;
        if (index >= 0 && index < rhs_it->second.arraySize) {
            if (lhs_it->second.type == rhs_it->second.type) {
                if (lhs_it->second.type == "int" || lhs_it->second.type == "float") {
                    lhs_it->second.numericValue = rhs_it->second.numericArray[index];
                } else if (lhs_it->second.type == "char" || lhs_it->second.type == "string" || lhs_it->second.type == "bool") {
                    lhs_it->second.textValue = rhs_it->second.textArray[index];
                } else {
                    std::string error = "Unsupported type in assignment: " + lhs_it->second.type;
                    yyerror(error.c_str());
                }
            } else {
                std::string error = "Type mismatch in assignment: " + std::string($1) + " and " + std::string($3);
                yyerror(error.c_str());
            }
        } else {
            std::string error = "Array index out of bounds: " + std::string($3);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1) + " or " + std::string($3);
        yyerror(error.c_str());
    }
}

    | ID ASSIGN exp ';' {
    auto it = symbolTable.find($1);
    if (it != symbolTable.end()) {
        // Check if the type of ID is 'int' or 'float'
        if (it->second.type == "int" || it->second.type == "float") {
            // Perform the assignment
            it->second.numericValue = $3;
        } else {
            // Error handling for incompatible type
            std::string error = "Type mismatch: cannot assign to variable '" + std::string($1) + "' of type '" + it->second.type + "'";
            yyerror(error.c_str());
        }
    } else {
        // Error handling for undeclared variable
        std::string error = "Variable not declared: " + std::string($1);
        yyerror(error.c_str());
    }
}
| ID '[' NR ']' ASSIGN ID ';' {
    auto lhs_it = symbolTable.find($1);
    auto rhs_it = symbolTable.find($6);
    if (lhs_it != symbolTable.end() && rhs_it != symbolTable.end()) {
        int index = (int)$3;
        if (index >= 0 && index < lhs_it->second.arraySize) {
            if (lhs_it->second.type == rhs_it->second.type) {
                if (lhs_it->second.type == "int" || lhs_it->second.type == "float") {
                    lhs_it->second.numericArray[index] = rhs_it->second.numericValue;
                } else if (lhs_it->second.type == "char" || lhs_it->second.type == "string" || lhs_it->second.type == "bool") {
                    lhs_it->second.textArray[index] = rhs_it->second.textValue;
                } else {
                    std::string error = "Unsupported type in assignment: " + lhs_it->second.type;
                    yyerror(error.c_str());
                }
            } else {
                std::string error = "Type mismatch in assignment: " + std::string($1) + " and " + std::string($6);
                yyerror(error.c_str());
            }
        } else {
            std::string error = "Array index out of bounds: " + std::string($1) + " at index " + std::to_string(index);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1) + " or " + std::string($6);
        yyerror(error.c_str());
    }
}
| ID '[' NR ']' ASSIGN ID '[' NR ']' ';' {
    auto lhs_it = symbolTable.find($1);
    auto rhs_it = symbolTable.find($6);
    if (lhs_it != symbolTable.end() && rhs_it != symbolTable.end()) {
        int lhs_index = (int)$3;
        int rhs_index = (int)$8;
        if (lhs_index >= 0 && lhs_index < lhs_it->second.arraySize && rhs_index >= 0 && rhs_index < rhs_it->second.arraySize) {
            if (lhs_it->second.type == rhs_it->second.type) {
                if (lhs_it->second.type == "int" || lhs_it->second.type == "float") {
                    lhs_it->second.numericArray[lhs_index] = rhs_it->second.numericArray[rhs_index];
                } else if (lhs_it->second.type == "char" || lhs_it->second.type == "string" || lhs_it->second.type == "bool") {
                    lhs_it->second.textArray[lhs_index] = rhs_it->second.textArray[rhs_index];
                } else {
                    std::string error = "Unsupported type in assignment: " + lhs_it->second.type;
                    yyerror(error.c_str());
                }
            } else {
                std::string error = "Type mismatch in assignment between arrays: " + std::string($1) + " and " + std::string($6);
                yyerror(error.c_str());
            }
        } else {
            std::string error = "Array index out of bounds: " + std::string($1) + " at index " + std::to_string(lhs_index) + " or " + std::string($6) + " at index " + std::to_string(rhs_index);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1) + " or " + std::string($6);
        yyerror(error.c_str());
    }
}

| ID '[' NR ']' ASSIGN CHAR_LITERAL ';' {
    auto var_it = symbolTable.find($1);
    if (var_it != symbolTable.end() && var_it->second.type == "char") {
        int index = (int)$3;
        if (index >= 0 && index < var_it->second.arraySize) {
            var_it->second.textArray[index] = $6[1]; // Extract the character from CHAR_LITERAL
        } else {
            std::string error = "Array index out of bounds: " + std::string($1) + " at index " + std::to_string(index);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared as char array: " + std::string($1);
        yyerror(error.c_str());
    }
}

| ID '[' NR ']' ASSIGN BOOL_LITERAL ';' {
    auto var_it = symbolTable.find($1);
    if (var_it != symbolTable.end()) {
        int index = (int)$3;
        if (index >= 0 && index < var_it->second.arraySize && var_it->second.type == "bool") {
            var_it->second.textArray[index] = $6; // Save the bool value
        } else {
            std::string error = "Array index out of bounds or type mismatch: " + std::string($1);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1);
        yyerror(error.c_str());
    }
}

| ID '[' NR ']' ASSIGN STRING_LITERAL ';' {
    auto var_it = symbolTable.find($1);
    if (var_it != symbolTable.end()) {
        int index = (int)$3;
        if (index >= 0 && index < var_it->second.arraySize && var_it->second.type == "string") {
            var_it->second.textArray[index] = $6; // Save the string value
        } else {
            std::string error = "Array index out of bounds or type mismatch: " + std::string($1);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1);
        yyerror(error.c_str());
    }
}

| ID '[' NR ']' ASSIGN exp ';' {
    auto var_it = symbolTable.find($1);
    if (var_it != symbolTable.end()) {
        int index = (int)$3; 
        std::cout << "Debug: Assigning to array '" << $1 << "' at index " << index << std::endl;
        if (index >= 0 && index < var_it->second.arraySize) {
            // If variable is of int type, check if the result of the expression is an integer
            if (var_it->second.type == "int" && floor($6) != $6) {
                std::string error = "Type mismatch: cannot assign non-integer value to array '" + std::string($1) + "' at index " + std::to_string(index);
                yyerror(error.c_str());
            } else {

                var_it->second.numericArray[index] = $6;
            }
        } else {
            std::string error = "Array index out of bounds: " + std::string($1) + " at index " + std::to_string(index);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared: " + std::string($1);
        yyerror(error.c_str());
    }
}


| ID '[' NR ']' ASSIGN bool_statement ';' {
    auto var_it = symbolTable.find($1);
    if (var_it != symbolTable.end() && var_it->second.type == "bool") {
        int index = (int)$3;
        if (index >= 0 && index < var_it->second.arraySize) {
            var_it->second.textArray[index] = $<value>6 ? "true" : "false";
        } else {
            std::string error = "Array index out of bounds for boolean array: " + std::string($1) + " at index " + std::to_string(index);
            yyerror(error.c_str());
        }
    } else {
        std::string error = "Variable not declared as boolean array: " + std::string($1);
        yyerror(error.c_str());
    }
}


| ID ASSIGN bool_statement ';' {
    auto it = symbolTable.find($1);
    if (it != symbolTable.end() && it->second.type == "bool") {
        it->second.numericValue = $3 ? 1 : 0; // Store boolean as numeric (1 for true, 0 for false)
        if(it->second.numericValue==0)
        it->second.textValue="false";
        else 
                it->second.textValue="true";
    } else {
        std::string error = "Variable not found or type mismatch: " + std::string($1);
        yyerror(error.c_str());
    }
}

            ;
bool_statement:
    exp { $$ = $1; }  
  | bool_statement AND bool_statement { $$ = $1 && $3; }
  | bool_statement OR bool_statement { $$ = $1 || $3; }
  | NEG bool_statement { $$ = !$2; }
  | exp EQ exp { $$ = $1 == $3; }
  | exp NEQ exp { $$ = $1 != $3; }
  | exp '<' exp { $$ = $1 < $3; }
  | exp LEQ exp { $$ = $1 <= $3; }
  | exp '>' exp { $$ = $1 > $3; }
  | exp GEQ exp { $$ = $1 >= $3; }
  | '(' bool_statement ')' { $$ = $2; }
  ;


exp:  NR                { $$ = $1;         }
    | exp '+' exp        { $$ = $1 + $3;    }
    | exp '-' exp        { $$ = $1 - $3;    }
    | exp '*' exp        { $$ = $1 * $3;    }
    | exp '/' exp        { $$ = $1 / $3;    }
    | '-' exp  %prec NEG { $$ = -$2;        }
    | '(' exp ')'        { $$ = $2;         }
   | ID {
        auto it = symbolTable.find($1);
        if (it != symbolTable.end()) {
            if (it->second.type == "int" || it->second.type == "float") {
                $$ = it->second.numericValue;
            } else {
                // Handle error for non-numeric types or implement logic as needed
                std::string error = "Non-numeric type used in expression: " + std::string($1);
                yyerror(error.c_str());
                $$ = 0.0; // Default value in case of error
            }
        } else {
            std::string error = "Undefined variable used in expression: " + std::string($1);
            yyerror(error.c_str());
            $$ = 0.0; // Default value in case of error
        }
    }
    
    | ID '[' NR ']' {
        auto it = symbolTable.find($1);
        if (it != symbolTable.end()) {
            int index = (int)$3;
            if (index >= 0 && index < it->second.arraySize) {
                if (it->second.type == "int" || it->second.type == "float") {
                    $$ = it->second.numericArray[index];
                } else {
                    std::string error = "Non-numeric type in array used in expression: " + std::string($1);
                    yyerror(error.c_str());
                    $$ = 0.0; // Default value in case of error
                }
            } else {
                std::string error = "Array index out of bounds: " + std::string($1);
                yyerror(error.c_str());
                $$ = 0.0; // Default value in case of error
            }
        } else {
            std::string error = "Undefined array used in expression: " + std::string($1);
            yyerror(error.c_str());
            $$ = 0.0; // Default value in case of error
        }
    }
    /* other existing rules */
    ;
   function_call:
    ID '(' argument_list ')' ';' {
        std::string functionName = $1;
        auto funcIt = functionMap.find(functionName);
        if (funcIt != functionMap.end()) {
            Function& func = funcIt->second;
            if (validateFunctionCall($1)) {
                std::cout << "Function called: " << functionName << std::endl;
            } else {
                std::cerr << "Argument mismatch for function call to " << functionName << std::endl;
            }
        } else {
            std::cerr << "Function not defined: " << functionName << std::endl;
        }
        tempArgumentTypes.clear();
    }
    ;
    argument_list:
    /*empty */
    |argument
    |argument_list ',' argument
    ;
argument:
ID '[' ']' {
    // Check if it's an array and add "array" to its type
    auto varIt = symbolTable.find($1);
    if (varIt != symbolTable.end()) {
        if (symbolTable[$1].arraySize != 0) {
            // It's an array, so add its type followed by "[]" to indicate an array type
            tempArgumentTypes.push_back(symbolTable[$1].type + "[]");
        } else {
            // Found in symbol table, but not an array
            std::cerr << "Not an array: " << $1 << std::endl;
        }
    } else {
        // Not found in symbol table
        std::cerr << "Array variable not declared: " << $1 << std::endl;
    }
}

| ID '[' NR_INT ']' {
        // Check if the array index is within bounds
        
        auto varIt = symbolTable.find($1);
        if (varIt != symbolTable.end() && $3 >= 0 && $3 < varIt->second.arraySize) {
        std::cout<<"verificare"<<std::endl;
            tempArgumentTypes.push_back(varIt->second.type);
        } else {
            std::cerr << (varIt == symbolTable.end() ? "Array variable not declared: " : "Array index out of bounds: ") << $1 << std::endl;
        }
    }
    
|  ID {
    // Retrieve the type of the variable from the symbol table and add to tempArgumentTypes
    auto varIt = symbolTable.find($1);
    if (varIt != symbolTable.end()) {
        if (varIt->second.arraySize == 0) {  // Ensure it's not an array
            tempArgumentTypes.push_back(varIt->second.type);
        } else {
            std::cerr << "Array used as simple variable: " << $1 << std::endl;
        }
    } else {
        std::cerr << "Variable not declared: " << $1 << std::endl;
    }
}


    ;
NR:
NR_INT| NR_F
;
%%

int main() {
    if (yyparse() == 0) {
        std::cout << "Parsing completed successfully." << std::endl;
    } else {
        std::cout << "Parsing failed." << std::endl;
    }
    //delete function pointer
 if (currentFunction != nullptr) {
            delete currentFunction;
            currentFunction = nullptr;
        }
        
    std::ofstream varFile("variable_table.txt");
    std::ofstream funcFile("function_table.txt");

    // Check if files are open
    if (!varFile.is_open() || !funcFile.is_open()) {
        std::cerr << "Error opening output files." << std::endl;
        return 1;
    }
// Variable table output
    for (const auto& pair : symbolTable) {
        varFile << "Variable " << pair.first << " is of type " << pair.second.type;
        if(pair.second.arraySize==0){
        if (pair.second.type == "int" || pair.second.type == "float") {
            varFile << " with numeric value " << pair.second.numericValue << std::endl;
        } else if (pair.second.type == "string" || pair.second.type == "char"||pair.second.type == "bool") {
            varFile << " with text value '" << pair.second.textValue << "'" << std::endl;
        }
        }

// Array output
        if (pair.second.arraySize > 0) {
            varFile << " Array values: ";
            for (int i = 0; i < pair.second.arraySize; i++) {
                if (pair.second.type == "int" || pair.second.type == "float") {
                    varFile << pair.second.numericArray[i] << " ";
                } else {
                    varFile << pair.second.textArray[i] << " ";
                }
            }
            varFile << std::endl;
        }
    }

    // Function table output
 for (const auto& pair : functionMap) {
        const Function& func = pair.second;
        funcFile << "Function Name: " << func.name << std::endl;
        funcFile << "Return Type: " << func.returnType << std::endl;

        if (func.parameterCounter > 0) {
            funcFile << "Parameters: ";
            for (int i = 0; i < func.parameterCounter; ++i) {
                funcFile << func.parameterTypes[i] << " " << func.parameterNames[i];
                if (i < func.parameterCounter - 1) {
                    funcFile << ", ";
                }
            }
        } else {
            funcFile << "No parameters";
        }
        funcFile << std::endl << std::endl;
    }


    varFile.close();
    funcFile.close();

    return 0;
}

