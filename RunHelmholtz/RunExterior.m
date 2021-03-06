function RunExterior

LastKnownVersionOfTools = '2.0.0.0';
try
    ver = Tools.Version();
    if ~strcmp(ver,LastKnownVersionOfTools)
        error('MDP:wrong version of Tools, expected version %s, found version %s',LastKnownVersionOfTools,ver);
    end
catch err
    if strcmp(err.identifier, 'MATLAB:undefinedVarOrClass')
        error('MDP: please add parent folder to the path');
    else%if strcmp(err.identifier,'MDP:wrong version of Tools')
        sprintf(err.message);
        rethrow(err);
    end
end

etinf=[];     
a=1;%1.8;    
B=a/2;
r0=0.3; r1=2.2;
%r0=0.8; r1=2.2;
NHR=1.6;



Problem = 'Dirichlet'; % 'Dirichlet' or 'Neumann'
KindOfConvergance = 'Grid';%'Exact' or 'Grid'
HankOrPlane = 'PlaneWave';% 'PlaneWave' or 'Hankel'
ScatType = 'ellipse';%'StarShapedScatterer'; %'ellipse' or 'circle' or ''StarShapedScatterer'
BType = 'Fourier'; % 'Fourier' or 'Chebyshev'
ChebyshevRange = struct('a',-pi,'b',pi);%don't change it
HankelIndex = 3;
HankelType = 2;


for b=B %[0.9,0.6,0.35] %[0.12,0.18,0.36,0.6,0.9] %[0.9,0.6,0.35] %[0.1, 0.2, 0.5] [0.69,0.66,0.63]% 0.69%
	
	%Parameterization  = Tools.Parameterizations.ParametricEllipse(struct('a',a,'b',b));
	%Parameterization  = Tools.Parameterizations.ParametricKite(struct('a',1,'b',.65*2,'c',1.5));
	Parameterization  = Tools.Parameterizations.ParametricSubmarine(struct('a',1.8,'b',1.8/5,'c',2,'p',100));
	
fprintf('Grid: r0=%f, r1=%f \n %s \n',r0,r1, Parameterization.toString());

	
    FocalDist = sqrt(a^2-b^2);
    Eta0 = acosh(a/FocalDist);
    R0 =1;
    
    if strcmpi(KindOfConvergance,'Grid')
        str = 'grid convergence';
    elseif strcmpi(KindOfConvergance,'Exact')
        str = 'convergance to exact solution';
        if strcmpi(HankOrPlane,'PlaneWave') && ~(a==1 && b==0.8 && r0 == 0.7*b && r1 == 1.8*a),  error('are you sure?'),end
    end
    
    fprintf('%s problem, cmpr using %s, data is %s, scatterer is %s, Basis is %s, Hnkl_n=%d \n',Problem,str,HankOrPlane,ScatType,BType,HankelIndex);
	if strcmpi(ScatType,'ellipse')
		fprintf('ExtrnlHomo problem about ellipse of FD=%d, ,Eta0=%d, a=%d, b=%d, AR=%d ,r0=%d,r1=%d\n',FocalDist, Eta0 , a,b,a/b,r0,r1);
	end
    if strcmpi(ScatType,'ellipse')
        ExParams  = struct('ScattererType','ellipse','eta',Eta0,'FocalDistance',FocalDist, 'HankelIndex', HankelIndex,'HankelType',HankelType);
    elseif strcmpi(ScatType,'circle')
        ExParams  = struct('ScattererType','circle','r',R0, 'HankelIndex', HankelIndex,'HankelType',HankelType);
    elseif strcmpi(ScatType,'StarShapedScatterer')
        ExParams = struct('ScattererType','StarShapedScatterer','Parameterization',Parameterization);
    end
    
rat=4/5;

%Ordr=4;
%Op1=Ordr+1;

%p=3;
%DX=abs(r0-r1)./(2.^(1:9+p));
%K=( (8.^Op1) * ( DX(5) .^Ordr ) .* (  DX.^(-Ordr))).^(1./Op1);

%for k= 6.*[2^(-4*rat),2^(-3*rat),2^(-2*rat),2^(-rat),1,2^(rat),2^(2*rat),2^(3*rat),2^(4*rat)]

    for k =1%[1,5,10]%[1,10,25] %[3,5,15,30]%[1,10,25]  %[1,5,10,15,20,25] % [1,3,5,10]
		
		ErrPre = 0; 
		
%for n = 1:6
%k=K(n);
        for  IncAngD =0;%0:10:90 %[0,50]%[0,15,35,50] % 0:15:90 %[0,50,100,150,200]
    		IncAng = IncAngD*pi/180;   

        if strcmpi(HankOrPlane,'PlaneWave')                        
            f1      = @(phi) -Uinc(ExParams,phi,IncAng,k);
            dfdn    = @(phi) -detaUinc(ExParams,phi,IncAng,k);           
        elseif strcmpi(HankOrPlane,'Hankel')
            f1      = @(phi) ExactHank(ExParams,phi,k);
            dfdn    = @(phi) dnExactHank(ExParams,phi,k);
        end
        
        if strcmpi(BType,'Chebyshev')
            Basis = Tools.Basis.ChebyshevBasis.BasisHelper(f1,dfdn,ChebyshevRange);
        elseif strcmpi(BType,'Fourier')
            Basis = Tools.Basis.FourierBasis.BasisHelper(f1,dfdn,[1e-06,1e-06]);%105);
        end
      
        %WaveNumberHandle = @Tools.Coeffs.ConstantWaveNumber;
        %WaveNumberParams = struct('k',k,'r0',NHR);
                
        for n=1:4 %run different grids
            tic
            %build grid
            
            p=6;%1;
            Nr=2^(n+p)+1;	Nth=2^(n+p)+1;
           
            %Grid                = Tools.Grid.PolarGrids(r0,r1,Nr,Nth);
            
            if strcmpi(ScatType,'ellipse')
                ScattererHandle  = @Tools.Scatterer.EllipticScatterer;               %External
                ScattererParams  = struct('Eta0',Eta0,'FocalDistance',FocalDist,'Stencil',9);
                Extension = @Tools.Extensions.TwoTupleExtension;
            elseif strcmpi(ScatType,'circle')
                ScattererHandle  = @Tools.Scatterer.PolarScatterer;                
                ScattererParams  = struct('r0',R0,'ExpansionType',15,'Stencil',9);
                Extension        = @Tools.Extensions.EBPolarHomoHelmholtz5OrderExtension;%EBPolarHomoHelmholtz7OrderExtension;;
            elseif strcmpi(ScatType,'StarShapedScatterer')
                ScattererHandle  = @Tools.Scatterer.StarShapedScatterer;
                ScattererParams  = ExParams;
                ScattererParams.Stencil = 9;
                Extension = @Tools.Extensions.TwoTupleExtension;
			end
            
			CollectRhs = 0;
			
            ExtPrb =  Solvers.ExteriorSolver( struct(...
                      'Basis'           , Basis, ...
                      'Grid'            , Tools.Grid.PolarGrids(r0,r1,Nr,Nth), ...
                      'CoeffsHandle'    , @Tools.Coeffs.ConstantWaveNumber, ...
                      'CoeffsParams'    , struct('k',k,'r0',NHR), ...
                      'ScattererHandle' , ScattererHandle, ...
                      'ScattererParams' , ScattererParams, ...
                      'CollectRhs'      , 0, ... %i.e. not
                      'Extension'       , Extension, ...
                      'ExtensionParams' , [] ...
                      ));
            
            Q0 = ExtPrb.Q0;%(:,1:2*M+1);
            Q1 = ExtPrb.Q1;%(:,2*M+2:4*M+2);
            
            xi = spalloc(Nr,Nth-1,length(ExtPrb.GridGamma));
            
            if strcmpi(Problem , 'Dirichlet')
                cn1 =( Q1 \ ( -Q0*Basis.cn0 )) ; 
                xi(ExtPrb.GridGamma) = ExtPrb.W0(ExtPrb.GridGamma,:)*Basis.cn0 + ExtPrb.W1(ExtPrb.GridGamma,:)*cn1;
            elseif strcmpi(Problem , 'Neumann') 
                cn0 =( Q0 \ ( -Q1*Basis.cn1 )) ; 
                xi(ExtPrb.GridGamma) = ExtPrb.W0(ExtPrb.GridGamma,:)*cn0 + ExtPrb.W1(ExtPrb.GridGamma,:)*Basis.cn1;
            else
                error('Solving only Dirichlet or Neumann problem')
            end
%             bn=5;
%             xi(ExtPrb.GridGamma) = besselh(bn,HankelType,k*Grid.R(ExtPrb.GridGamma)).*exp(bn*1i*Grid.Theta(ExtPrb.GridGamma));
%             
            
%             u = spalloc(Nr,Nth-1,length(ExtPrb.Nm));
%             
%             GLW = ExtPrb.Solve(xi);
%             
%             u(ExtPrb.Nm)=GLW(ExtPrb.Nm);


                u = ExtPrb.P_Omega(xi);


            %%%%%%%%%%%%%%
            
            t=toc;
            
% % % % % % % % % % % % % % % %
% Comparison
% % % % % % % % % % % % % % % %
        if strcmpi(KindOfConvergance,'Grid')
            if n > 1
                u1= spalloc(Nr,Nth-1,nnz(u0));
                u1(ExtPrb.Nm) = u0(ExtPrb.Nm);
                
                tmp = u(1:2:end,1:2:end)-u1(1:2:end,1:2:end);
                
                %etinf(n) =norm(tmp(:),inf);
				ErrTot = norm(tmp(:),inf);
                %fprintf('k=%d,M=%d,N=%-10dx%-10d\t etinf=%d\ttime=%d\n',k,Basis.M, Nr,Nth,full(etinf(n)),t);
				fprintf('k=%d,NBss0=%d,NBss1=%d,N=%-10dx%-10d\t ErrTot=%d\t rate=%-5.2f\t time=%d\n',k,Basis.NBss0,Basis.NBss1, Nr,Nth,ErrTot,log2(ErrPre/ErrTot),t);
				
				ErrPre = ErrTot;
				
				
 % fprintf('k=%-5.4f,pf=%-5.4f,pf=%-5.4f,IncAng=%d,M=%d,N=%-10dx%-10d\t etinf=%d\ttime=%d\t \n',k,  (k^5)* Grid.dx^4, (k^5) * Grid.dy^4,IncAngD,Basis.M, Nr,Nth,full(etinf(n)),t);
           
            end
            
            u0=spalloc(Nr*2-1,Nth*2-2,nnz(u));
            u0(1:2:end,1:2:end)=u;
        
        elseif strcmpi(KindOfConvergance,'Exact')
%            phi = linspace(0,2*pi,300);
             phi = linspace(-pi,pi,300);
            
            app = 0;

            if strcmpi(Problem , 'Dirichlet')
                for j=1:numel(Basis.Indices)
                    bj = Basis.Handle(phi,Basis.Indices(j),Basis.AddParams);
                    app = app + cn1(j).*bj.xi0;
                end
                
                if strcmpi(HankOrPlane,'PlaneWave')
                    ex = ell_du_dn_exact_SM(a,b,k,phi,IncAng)';
                elseif strcmpi(HankOrPlane,'Hankel')
                    %                         ex = dnExactHank(ExParams,phi,k);????
                    ex = dnExactHank(ExParams,-phi,k);
                end
                
                % error('Dirichlet problem not implemented yet')
            elseif strcmpi(Problem , 'Neumann')
                for j=1:numel(Basis.Indices)
                    bj = Basis.Handle(phi,Basis.Indices(j), ExtPrb.Scatterer.MetricsAtScatterer,Basis.AddParams);
                    app = app + cn0(j).*bj.xi0;
                    %                 for j=-M:M
                    %                     app= app +  cn0(j+M+1).*exp(1i*j*phi);
                    %du_app = du_app + cn1(j+M+1).*exp(1i*j*phi);
                end
                
                if strcmpi(HankOrPlane,'PlaneWave')
                    ex = ell_hard_exact_Sol(a,b,k,IncAng,phi)';
                elseif strcmpi(HankOrPlane,'Hankel')
                    ex = ExactHank(ExParams,phi,k);
                end
            else
                error('Solving only Dirichlet or Neumann problem')
            end
        
            ex=ex/norm(ex,inf);
            app=app/norm(app,inf);
            
            tmp = app(:) - ex(:);
            etinf(n) =norm(tmp(:),inf);
            fprintf('k=%d,IncAng=%d,M=%d,N=%-10dx%-10d\t etinf=%d\ttime=%d\n',k,IncAngD,Basis.M, Nr,Nth,full(etinf(n)),t);

            
        else
            error('undefinded comparison method');
        end
            
         %     if n>1 && etinf(n)<5*10^-6, break, end  % to make polution test faster
        end
        
fprintf('\n');
     %   Linf=log2(etinf(1:end-1)./etinf(2:end))
%        Lbinf=log2(ebinf(1:end-1)./ebinf(2:end))
        end
        
    end
end

end


function uinc = Uinc(Params,phi,IncAng,k)  
    
    if strcmpi(Params.ScattererType,'ellipse')
         x = Params.FocalDistance * cosh(Params.eta) .* cos(phi);
         y = Params.FocalDistance * sinh(Params.eta) .* sin(phi);
    elseif strcmpi(Params.ScattererType,'circle')
        x = Params.r .* cos(phi);
        y = Params.r .* sin(phi);
    elseif strcmpi(Params.ScattererType,'StarShapedScatterer')
        try
            x = Params.Parameterization.XHandle.Derivatives(phi);
            y = Params.Parameterization.YHandle.Derivatives(phi);
        catch
            x = Params.r.*cos(phi);
            y = Params.r.*sin(phi);
        end

    end
 
    uinc = exp( 1i.* k .* (x.*cos(IncAng) + y.*sin(IncAng)) );
end

function duinc = detaUinc(Params,phi,IncAng,k)
    
    if strcmpi(Params.ScattererType,'ellipse')
        dx = Params.FocalDistance * sinh(Params.eta) .* cos(phi);
        dy = Params.FocalDistance * cosh(Params.eta) .* sin(phi);
    elseif strcmpi(Params.ScattererType,'circle')
        dx = cos(phi);
        dy = sin(phi);
    elseif strcmpi(Params.ScattererType,'StarShapedScatterer')
        [x,dx] = Params.Parameterization.XHandle.Derivatives(phi);
        [y,dy] = Params.Parameterization.YHandle.Derivatives(phi);
    end
    
   
    
    uinc = Uinc(Params,phi,IncAng,k)  ;
    
    duinc = 1i .* k .*  uinc .* (dx.*cos(IncAng) + dy.*sin(IncAng));
 %   h = FocalDist*sqrt(sinh(eta).^2 + sin(phi).^2);
   % duinc = duinc./h;

   if strcmpi(Params.ScattererType,'StarShapedScatterer')
	   h = sqrt(dx.^2 + dy.^2);
	   duinc = 1i .* k .*  uinc .* (dy.*cos(IncAng) - dx.*sin(IncAng))./h;
   end
   
end


function u = ExactHank(Params,phi,k)
    if strcmpi(Params.ScattererType,'ellipse')
        x = Params.FocalDistance * cosh(Params.eta) .* cos(phi);
        y = Params.FocalDistance * sinh(Params.eta) .* sin(phi);
    elseif strcmpi(Params.ScattererType,'circle')
        x = Params.r .* cos(phi);
        y = Params.r .* sin(phi);
%         r= Params.r;
%         th = phi;
    end

            Z=x+1i*y;
        r=abs(Z);
        th=angle(Z);

    
    
    bn=Params.HankelIndex;
    u = besselh(bn,Params.HankelType,k*r).*exp(bn*1i*th);
end

function un = dnExactHank(Params,phi,k)
    
    if strcmpi(Params.ScattererType,'ellipse')
        x = Params.FocalDistance * cosh(Params.eta) .* cos(phi);
        y = Params.FocalDistance * sinh(Params.eta) .* sin(phi);
    elseif strcmpi(Params.ScattererType,'circle')
                x = Params.r .* cos(phi);
                y = Params.r .* sin(phi);
%         r= Params.r;
%         th = phi;
    end
    
    Z=x+1i*y;
    r=abs(Z);
    th=angle(Z);
    
    bn=Params.HankelIndex;
    
    dudr  = k*0.5*(besselh(bn-1,Params.HankelType,k*r) - besselh(bn+1,Params.HankelType,k*r)).*exp(bn*1i*th);
    
    if strcmpi(Params.ScattererType,'ellipse')
        
        dudth  = 1i*bn*besselh(bn,Params.HankelType,k*r).*exp(bn*1i*th);
        
        drdeta = Params.FocalDistance^2 * cosh(Params.eta).*sinh(Params.eta) ./r;
        dthdeta = Params.FocalDistance^2 * cos(phi).*sin(phi) ./(r.^2);
        un = dudr.*drdeta + dudth.*dthdeta;
        
%         SM = EllipticalMetrics(Params.FocalDistance,Params.eta,phi);
       % un = un.*SM.h;
    elseif strcmpi(Params.ScattererType,'circle')
        un = dudr;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



