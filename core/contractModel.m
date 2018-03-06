function [reducedModel, removedRxns]=contractModel(model, distReverse)
% contractModel
%   Contracts a model by grouping all identical reactions. Similar to the
%   deleteDuplicates part in simplifyModel but more care is taken here
%   when it comes to gene associations
%
%   model           a model structure
%   distReverse     distinguish reactions with same metabolites but different
%                   reversibility as different reactions (opt, default true)
%
%   reducedModel    a model structure with grouped reactions
%   removedRxns     cell array for the removed duplicate reactions
%
%   NOTE: This code might not work for advanced grRules strings
%         that involve nested expressions of 'and' and 'or'.
%
%   Usage: [reducedModel, removedRxns]=contractModel(model, distReverse)
%
%   Rasmus Agren,     2014-01-08
%   Hao Wang,         2018-03-06  Add parameter distReverse to enable overlooking
%                                 reaction reversibility when detecting
%                                 duplication; Restructure removedRxns cell
%                                 array for retaining the assocation between
%                                 duplicated reactions
% 

if nargin<2
    distReverse=true;
end

%First sort the model so that reversible reactions are in the same
%direction
modelS=sortModel(model);

%Get a list of duplicate reactions
if distReverse
    x=[modelS.S; model.rev']';
else
    x=modelS.S';
end
[~,I,J] = unique(x,'rows','first');

%Initialize cell array of removedRxns
removedRxns=cell(numel(model.rxns),1);
removedRxns(:)={''};

duplicateRxns=setdiff(1:numel(model.rxns),I);
mergeTo=I(J(duplicateRxns));

%Now add all the info from this one. Print a warning if they have different
%bounds or objective function coefficients. Uses the widest bounds and largest
%magnitude of objective coefficient
for i=1:numel(duplicateRxns)
    if model.lb(duplicateRxns(i))<model.lb(mergeTo(i))
       EM=['Duplicate reaction ' model.rxns{duplicateRxns(i)} ' has wider lower bound. Uses the most negative/smallest lower bound'];
       dispEM(EM,false);
       model.lb(mergeTo(i))=model.lb(duplicateRxns(i));
    end
    if model.ub(duplicateRxns(i))>model.ub(mergeTo(i))
       EM=['Duplicate reaction ' model.rxns{duplicateRxns(i)} ' has wider upper bound. Uses the most positive/largest upper bound'];
       dispEM(EM,false);
       model.ub(mergeTo(i))=model.ub(duplicateRxns(i));
    end
    if abs(model.c(duplicateRxns(i)))>abs(model.c(mergeTo(i)))
       EM=['Duplicate reaction ' model.rxns{duplicateRxns(i)} ' has a larger objective function coefficient. Uses the largest coefficient'];
       dispEM(EM,false);
       model.c(mergeTo(i))=model.c(duplicateRxns(i));
    end

    %Genes are added as 'or'
    if isfield(model,'rxnGeneMat')
        commonGenes=find(model.rxnGeneMat(duplicateRxns(i),:) & model.rxnGeneMat(mergeTo(i),:));
        newGenes=model.rxnGeneMat(duplicateRxns(i),:);
        newGenes(commonGenes)=0;
        model.rxnGeneMat(mergeTo(i),:)=model.rxnGeneMat(mergeTo(i),:)+newGenes;
    end
    if isfield(model,'grRules')
        if any(model.grRules{duplicateRxns(i)})
           if any(model.grRules{mergeTo(i)})
               %Split both grStrings on ' or ' and then put together union
               %with ' or '
               rules1=regexp(model.grRules{mergeTo(i)},' or ','split');
               rules2=regexp(model.grRules{duplicateRxns(i)},' or ','split');
               allRules=union(rules1,rules2);

               %Probably not the nicest way to do this
               model.grRules{mergeTo(i)}=allRules{1};
               for j=2:numel(allRules)
                   model.grRules{mergeTo(i)}=[model.grRules{mergeTo(i)} ' or ' allRules{j}];
               end
           else
               model.grRules{mergeTo(i)}=model.grRules{duplicateRxns(i)};
           end
        end
    end
    if isfield(model,'eccodes')
        if any(model.eccodes{duplicateRxns(i)})
           if any(model.eccodes{mergeTo(i)})
               %Split on ';' and put together the union with ';'
               codes1=regexp(model.eccodes{mergeTo(i)},';','split');
               codes2=regexp(model.eccodes{duplicateRxns(i)},';','split');
               codes=union(codes1,codes2);
               model.eccodes{mergeTo(i)}=codes{1};
               for j=2:numel(codes)
                  model.eccodes{mergeTo(i)}=[model.eccodes{mergeTo(i)} ';' codes{j}];
               end
           else
               model.eccodes{mergeTo(i)}=model.eccodes{duplicateRxns(i)};
           end
        end
    end
    
    %Generate removedRxns cell array
    if ~isequal(duplicateRxns(i),mergeTo(i))
        if isempty(removedRxns{mergeTo(i)})
            removedRxns{mergeTo(i)}=model.rxns{duplicateRxns(i)};
        else
            removedRxns{mergeTo(i)}=strcat(removedRxns{mergeTo(i)},';',model.rxns{duplicateRxns(i)});
        end
    end
end

%Delete the duplicate reactions
reducedModel=removeReactions(model,duplicateRxns);
[~, index]=ismember(reducedModel.rxns,model.rxns);
removedRxns=removedRxns(index);
end
