%% find required toolboxes
% write required MATLAB products to log file

clear all
clc

% recursively get all m files
fprintf('Generate list of all .m files...\n');
mfile_list = findmfiles('./');
n_files = length(mfile_list);
fprintf('Done! Found a total of %d .m files.\n\n', n_files);

% write all required products to file
fprintf('Getting required MATLAB products for...\n');
myfid = fopen('required_products.log', 'w');
for i_file = 1:n_files
    % output current status
    fprintf('file %d/%d\n', i_file, n_files);
    
    % write filename to log
    fprintf(myfid, [strrep(mfile_list{i_file},'\','\\'), '\n']);
    
    % get required products
    [fList, pList] = matlab.codetools.requiredFilesAndProducts(mfile_list{i_file});
    for i_product = 1:length(pList)
        % write required products to log
        fprintf(myfid, [pList(i_product).Name, '\n']);
    end
    fprintf(myfid,'\n');
end
fclose(myfid);

fprintf('\nDone! Check required_products.log for output.\n');


function [file_list] = findmfiles(directory)
    % recursively generate list of all m files
    
    % get list of elements in directory
    listing = dir(directory);
    
    % get number of files and directories
    n_elements = length(listing);
    n_dir = 0;
    for i_element = 1:n_elements
        n_dir = n_dir + double(listing(i_element).isdir);
    end
    n_fiels = n_elements - n_dir;
    
    % save file and directory paths
    file_list = cell(n_fiels,1);
    dir_list = cell(n_dir,1);
    i_dir = 1;
    i_file = 1;
    for i_element = 1:n_elements
        if listing(i_element).isdir
            if ~strcmp(listing(i_element).name, '.') && ~strcmp(listing(i_element).name, '..') 
                dir_list{i_dir} = [listing(i_element).folder, '\', listing(i_element).name];
                i_dir = i_dir + 1;
            end
        else
            if strcmp(listing(i_element).name(end-1:end),'.m')
                file_list{i_file} = [listing(i_element).folder, '\', listing(i_element).name];
                i_file = i_file + 1;
            end
        end
    end
    
    % remove empty elements from file list
    dir_list = dir_list(1:i_dir-1);
    file_list = file_list(1:i_file-1);
    
    % recursively go through all folders
    if isempty(dir_list)
        return
    else
        for i_dir = 1:n_dir-2
            % concatenate list of filenames
            file_list = [file_list;findmfiles(dir_list{i_dir})];
        end
    end
end



