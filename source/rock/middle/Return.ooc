import ../frontend/[Token,BuildParams]
import Visitor, Statement, Expression, Node, FunctionDecl, FunctionCall,
       VariableAccess, VariableDecl, AddressOf, ArrayAccess, If,
       BinaryOp, Cast, Type, Module
import tinker/[Response, Resolver, Trail]

Return: class extends Statement {
    
    expr: Expression = null
        
    init: func ~ret (.token) {
        init(null, token)
    }
    
    init: func ~retWithExpr (=expr, .token) {
        super(token)
    }
    
    accept: func (visitor: Visitor) { visitor visitReturn(this) }
    
    resolve: func (trail: Trail, res: Resolver) -> Response {
                
        idx := trail find(FunctionDecl)
        fDecl: FunctionDecl = null
        retType: Type = null
        if(idx != -1) {
            fDecl = trail get(idx) as FunctionDecl
            retType = fDecl getReturnType()
            if (!retType isResolved()) {
                return Responses LOOP
            }
        }
        
        if(!expr) {
            if (!retType isGeneric() && retType != voidType) { 
                token throwError("Function is not declared to return `null`! trail = %s" format(trail toString()))
            } else {
                return Responses OK
            }
        }
        
        {
            trail push(this)
            response := expr resolve(trail, res)
            trail pop(this)
            if(!response ok()) {
                return response
            }
        }
        
        if (retType) {            
                        
            if(retType isGeneric()) {
                if(expr getType() == null || !expr getType() isResolved()) {
                    res wholeAgain(this, "expr type is unresolved"); return Responses OK
                }
                
                returnAcc := VariableAccess new(fDecl getReturnArg(), token)
                
                if1 := If new(returnAcc, token)
                
                if(expr hasSideEffects()) {
                    vdfe := VariableDecl new(null, generateTempName("returnVal"), expr, expr token)
                    if(!trail peek() addBefore(this, vdfe)) {
                        token throwError("Couldn't add the vdfe before the generic return in a %s! trail = %s" format(trail peek() as Node class name, trail toString()))
                    }
                    expr = VariableAccess new(vdfe, vdfe token)
                }
                
                ass := BinaryOp new(returnAcc, expr, OpTypes ass, token)
                if1 getBody() add(ass)
                
                if(!trail peek() addBefore(this, if1)) {
                    token throwError("Couldn't add the assignment before the generic return in a %s! trail = %s" format(trail peek() as Node class name, trail toString()))
                }
                expr = null
                
                res wholeAgain(this, "Turned into an assignment")
                //return Responses OK
                return Responses LOOP
            }
            
            if(expr) {
                if(expr getType() == null || !expr getType() isResolved()) {
                    res wholeAgain(this, "Need info about the expr type")
                    return Responses OK
                }
                if(!retType getName() toLower() equals("void") && !retType equals(expr getType())) {
                    score := expr getType() getScore(retType)
                    if (score < (Type SCORE_SEED / 2)) {
                        
                        msg: String
                        if (res params veryVerbose) {
                            msg = "The declared return type (%s) and the returned value (%s) do not match!\nscore = %d\ntrail = %s" format(retType toString(), expr getType() toString(), score, trail toString())
                        } else {
                            msg = "The declared return type (%s) and the returned value (%s) do not match!" format(retType toString(), expr getType() toString())
                        }
                        res wholeAgain(this, msg)    
                        return Responses OK
                    }                       
                       //token throwError("The function's return type (%s) and the actual return value (%s) do not match!\nscore = %d\ntrail = %s"format(retType toString(), expr getType() toString(),score, trail toString()))
                    
                    expr = Cast new(expr, retType, expr token)
                }
            }
            
            if (retType == voidType && !expr) 
                token throwError("Function is declared to return `null`, not %s! trail = %s" format(expr getType() toString(), trail toString()))
            
            module := trail module()
            if (module simpleName == "ret_missmatch") {
                                score := retType getScore(expr getType())
                score toString() println()
            }
        }
        
        return Responses OK
        
    }

    toString: func -> String { expr == null ? "return" : "return " + expr toString() }
    
    replace: func (oldie, kiddo: Node) -> Bool {
        if(expr == oldie) {
            expr = kiddo
            return true
        }
        
        return false
    }

}


