#ifndef FUNCTION_STRUCT_HPP
#define FUNCTION_STRUCT_HPP

#include <string>
#include <iostream>
class Function {
public:
    std::string returnType;
    std::string name;
    std::string parameterTypes[5]; // Array to store types of parameters
    std::string parameterNames[5]; // Array to store names of parameters
    int parameterCounter; // Counter to keep track of the number of parameters
Function() : returnType(""), name(""), parameterCounter(0) {
        // Initialize arrays with default values if necessary
    }
    // Constructor to initialize function with return type and name
    Function(const std::string& returnType, const std::string& name) 
        : returnType(returnType), name(name), parameterCounter(0) {std::cout<<"function created."<<std::endl;}

    // Method to add a parameter to the function
    void addParameter(const std::string& type, const std::string& name) {
        if (parameterCounter < 5) { // Ensure we don't exceed the array bounds
            parameterTypes[parameterCounter] = type;
            parameterNames[parameterCounter] = name;
            parameterCounter++;
        } else {
            // Optionally handle the case where there are more than 5 parameters
            std::cerr << "Maximum number of parameters exceeded for function " << this->name << std::endl;
        }
    }
};



#endif // FUNCTION_STRUCT_HPP
