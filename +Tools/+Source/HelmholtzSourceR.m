classdef HelmholtzSourceR < Tools.Source.SuperHelmholtzSource
    properties (Dependent = true)
        Source;%Fn;Ff;Fnn;Fff;    % WN;
    end
    
    properties(Access = protected)       
        Scatterer; 
        Exact;
        IsExactReady=false;
        
        WaveNumberHndl;
        WaveNumberAddParams;        
    end
    
    methods
        function [F,Fn,Ff,Fnn,Fff] = Derivatives(obj,Ex)
            
            if obj.IsDummy
                F=0;
                Fn=0;
                Ff=0;
                Fnn=0;
                Fff=0;
            else
                if ~exist('Ex','var') 
                   if ~obj.IsExactReady
                       
                       WN = obj.WaveNumberHndl(obj.Scatterer,obj.WaveNumberAddParams);
                       
                       obj.Exact = Tools.Exact.ExactVarKr(obj.Scatterer, WN); 
                       obj.IsExactReady = true;
                   end
                    Ex = obj.Exact;
                end
                               
                [u,un,unn,uf,uff] = Ex.Derivatives();
                
                if nargout==1,  s                = Ex.calc_s();  end
                if nargout==2, [s,sr]            = Ex.calc_s();  end
                if nargout==3, [s,sr,srr]        = Ex.calc_s();  end
                if nargout==4, [s,sr,srr,st]     = Ex.calc_s();  end
                if nargout==5, [s,sr,srr,st,stt] = Ex.calc_s();  end
                
                F   = s.*u;
                                
                if nargout>1, Fr  = ur.*s + u.*sr;                          end
                if nargout>2, Frr = urr.*s + 2*ur.*sr + u.*srr;             end
                if nargout>3, F3r = u3r.*s + 3*urr.*sr + 3*ur.*srr + u.*s3r;end
                if nargout>4, Ftt = utt.*s + 2*ut.*st + u.*stt;             end
                if nargout>4, Frtt = urtt.*s + utt.*sr + 2*urt.*st + 2*ut.*srt + ur.*stt + u.* srtt;             end
            end
            
        end
            
        function obj = HelmholtzSourceR(Scatterer, WaveNumberHndl,WaveNumberAddParams,~)%(Exact)%(FocalDist,eta,phi,k0,r0)
                obj.Scatterer = Scatterer;
                obj.WaveNumberHndl = WaveNumberHndl;
                obj.WaveNumberAddParams = WaveNumberAddParams;
                obj.IsDummy = false;                
        end
        
        
        function S = get.Source(obj)
            S = spalloc(obj.Scatterer.Size(1),obj.Scatterer.Size(2),numel(obj.Scatterer.Np));
            
%             ScatGamma = struct('FocalDistance',obj.Scatterer.FocalDistance,'Eta', obj.Scatterer.Eta0,'Phi', obj.Scatterer.Phi(obj.Scatterer.GridGamma));
            
            WN            = obj.WaveNumberHndl(obj.Scatterer.TheScatterer,obj.WaveNumberAddParams);
            ExactOnGamma  = Tools.Exact.ExactElpsVarKr(obj.Scatterer.TheScatterer, WN);
            
            [F,Fr,Frr] = obj.Derivatives(ExactOnGamma);
            
            S(obj.Scatterer.GridGamma) = F + obj.Scatterer.dr.*Fr  + (obj.Scatterer.dr.^2).*Frr/2;%taylor
            
            tmp = obj.Derivatives();
            S(obj.Scatterer.Inside) = tmp(obj.Scatterer.Inside);   %was obj.Source(ETA<=obj.Eta0) = tmp(ETA<=obj.Eta0);
        end    
    end
    
end

