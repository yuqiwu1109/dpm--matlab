classdef ExteriorLaplacianSolver < Solvers.InteriorLaplacianSolver

	properties
% 		BC_y1;
% 		BC_yn;
% 		BC_x1;
% 		BC_xn;
	end
	
    methods
        function obj = ExteriorLaplacianSolver(Setup)
            obj = obj@Solvers.InteriorLaplacianSolver(Setup);     
			
% 			 Boundaries.R = [ sqrt(Grid.x(1)^2+ Grid.y(2:end-1).^2).' , ...
%                                  sqrt(Grid.x(end)^2+ Grid.y(2:end-1).^2).',  ...
%                                  sqrt(Grid.x(2:end-1).^2+ Grid.y(1).^2).',  ...
%                                  sqrt(Grid.x(2:end-1).^2+ Grid.y(end).^2).'   ...
%                                 ];
% 
% 			Exact	= Tools.Exact.ExLapCrclVarCoeffs346(Boundaries, SourceParams);
% 			
% 			obj.BC_x1 = Exact.u(:,1).';
% 			obj.BC_xn = Exact.u(:,2).';
% 			obj.BC_y1 = Exact.u(:,3);
% 			obj.BC_yn = Exact.u(:,4);
        end
        
        function u = P_Omega(obj,xi_gamma)
            
            rhs=zeros(obj.Grid.Nx,obj.Grid.Ny);
            
            rhs(obj.Scatterer.Mp)= obj.Lu(xi_gamma(:),obj.Scatterer.Mp);
            GLW = obj.Gf(rhs(:));
            
            u = spalloc(obj.Grid.Nx,obj.Grid.Ny,numel(obj.Scatterer.Nm));
			%u(obj.Scatterer.Nm)=xi_gamma(obj.Scatterer.Nm) - GLW(obj.Scatterer.Nm).';%( GLW(obj.Scatterer.Nm).' - xi_gamma(obj.Scatterer.Nm));
            GF = obj.GF{:};
			u(obj.Scatterer.Nm)=xi_gamma(obj.Scatterer.Nm)  + ( GLW(obj.Scatterer.Nm).' - xi_gamma(obj.Scatterer.Nm)) + GF(obj.Scatterer.Nm).';			
        end
    end
    
    methods(Access = protected)
                
        function Qj = Qcol(obj,GLW,w)
            Qj = GLW(obj.GridGamma,:)-w(obj.GridGamma,:);
        end
        
		function rhs = Bf(obj,F)
			%rhs = F(:);
			
            rhs = obj.Op.Bf(F);
            F=reshape(rhs,size(F));
			rhs = obj.Op.AdjustRhs(F);%,obj.BC_y1,obj.BC_yn,obj.BC_x1,obj.BC_xn);
            
			rhs = rhs(:);
            
		end
		
		function res = BF(obj)
			
			ScattererForSource = obj.Scatterer;
%             ScattererForSource.eta  = obj.Scatterer.eta;
%             ScattererForSource.phi = obj.Scatterer.phi;
%             ScattererForSource.fd  = obj.Scatterer.FocalDistance;
% 			
			HS = obj.SourceHandle(ScattererForSource,obj.CoeffsHandle,obj.CoeffsParams,obj.SourceParams);
			
			res = obj.Bf(HS.Source);
			res(obj.Scatterer.Inside())=0;
		end
	end
end
