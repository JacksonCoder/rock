import structs/ArrayList

import ../frontend/Token
import Expression, Type, Visitor, TypeDecl, Cast, FunctionCall, FunctionDecl,
	   Module, Node, VariableDecl, VariableAccess, BinaryOp, Argument, Return
import tinker/[Response, Resolver, Trail]

ClassDecl: class extends TypeDecl {

    DESTROY_FUNC_NAME   := static const "__destroy__"
    DEFAULTS_FUNC_NAME  := static const "__defaults__"
    LOAD_FUNC_NAME      := static const "__load__"

    isAbstract := false
    isFinal := false

    defaultInit: FunctionDecl = null
    
    init: func ~classDeclNoSuper(.name, .token) {
        super(name, token)
    }
    
    init: func ~classDeclNotMeta(.name, .superType, .token) {
        this(name, superType, false, token)
    }

    init: func ~classDecl(.name, .superType, =isMeta, .token) {
        super(name, superType, token)
    }
    
    accept: func (visitor: Visitor) { visitor visitClassDecl(this) }
    
    resolve: func (trail: Trail, res: Resolver) -> Response {

    	shouldDefault := false
	    for(vDecl in variables) {
			if(vDecl getExpr() != null) {
				shouldDefault = true
				break
			}
	    }
	    if(shouldDefault && functions get(DEFAULTS_FUNC_NAME) == null) {
			addFunction(FunctionDecl new(DEFAULTS_FUNC_NAME, token))
	    }
    
        {
            response := super resolve(trail, res)
            if(!response ok()) return response
        }
        
        return Responses OK
    }
    
    getBaseClass: func (fDecl: FunctionDecl) -> ClassDecl {
        sRef : ClassDecl  = getSuperRef()
		if(sRef != null) {
			base := sRef getBaseClass(fDecl)
			if(base != null) {
                return base
            }
		}
		if(getFunction(fDecl name, fDecl suffix, null, false) != null) return this
		return null
	}
    
    replace: func (oldie, kiddo: Node) -> Bool { false }

	addDefaultInit: func {
		if(!isAbstract && !isObjectClass() && !isClassClass() && defaultInit == null) {
			init := FunctionDecl new("init", token);
			addFunction(init);
			defaultInit = init;
		}
	}

    addFunction: func (fDecl: FunctionDecl) {
        
        if(isMeta) {
            if (fDecl getName() == "init" && !fDecl isExternWithName()) {
                addInit(fDecl)
            } else if (fDecl getName() == "new") {
                already := getFunction(fDecl getName(), fDecl getSuffix())
                // FIXME, just removing based off fDecl name for now (should take suffix into account)
                if (already != null) removeFunction(fDecl) 
            }
        }
	
		super addFunction(fDecl)
        
    }

	addInit: func(fDecl: FunctionDecl) {
		/* if defaultInit != null */
		
        newType := getNonMeta() getInstanceType() as BaseType
        
		constructor := FunctionDecl new("new", fDecl token)
        constructor setStatic(true)
		constructor setSuffix(fDecl getSuffix())
		retType := newType clone() as BaseType
		if(retType getTypeArgs()) retType getTypeArgs() clear()
		
		constructor getArguments() addAll(fDecl getArguments())
		constructor getTypeArgs() addAll(getTypeArgs())
		
        // why use getNonMeta() here? addInit() is called only in the
        // meta-class, remember?
        newTypeAccess := VariableAccess new(newType, fDecl token)
        newTypeAccess setRef(getNonMeta())
        allocCall := FunctionCall new(newTypeAccess, "alloc", fDecl token)
		cast := Cast new(allocCall, newType, fDecl token)
		vdfe := VariableDecl new(null, "this", cast, fDecl token)
		constructor getBody() add(vdfe)
		
        printf("[addInit for %s], got %d typeArgs\n", toString(), getTypeArgs() size())
		for (typeArg in getTypeArgs()) {
            printf("[addInit for %s], got typeArg %s\n", toString(), typeArg toString())
			e := VariableAccess new(typeArg getName(), constructor token)
			retType addTypeArg(e)
			
            thisAccess    := VariableAccess new("this",                   constructor token)
            typeArgAccess := VariableAccess new(thisAccess, typeArg name, constructor token)
            ass := BinaryOp new(typeArgAccess, e, OpTypes ass, constructor token)
			constructor getBody() add(ass)
		}
        
		constructor setReturnType(retType)
		
		thisAccess := VariableAccess new(vdfe, fDecl token)
		thisAccess setRef(vdfe)
		
        // TODO: add suffix handling
		initCall := FunctionCall new(fDecl getName(), fDecl token)
        initCall setExpr(VariableAccess new("this", fDecl token))
		for (arg in constructor getArguments()) {
			initCall getArguments() add(VariableAccess new(arg, fDecl token))
		}
		constructor getBody() add(initCall)
		constructor getBody() add(Return new(thisAccess, fDecl token))
		
		addFunction(constructor)	
	}
}

