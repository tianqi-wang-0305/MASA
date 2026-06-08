classdef Parameter < Simulink.Parameter
  methods
    %---------------------------------------------------------------------------
    function setupCoderInfo(h)
      % Use custom storage classes from this package
      useLocalCustomStorageClasses(h, 'NoneSAR');
    end

    function h = Parameter(varargin)
        %PARAMETER  Class constructor.

        % Call superclass constructor with variable arguments
        h@Simulink.Parameter(varargin{:});
    end % end of constructor
  end % methods
  %------- Add members for conversion definition -> used in grl/a2l files
  properties(PropertyType = 'char', AllowedValues = {'None'; 'Formular'; 'Linear'; 'StringRange'})
    %-Type of Conversion
	ConversionType = 'None';
  end
  properties(PropertyType = 'char')
    %-Description of the conversion
	ConversionDescription = '';
  end

  % properties for conversion type 'String Range'
  properties
    %-if conversion type StringRange is set the specific tables must be placed in this attribute
	ConversionStringRange = [];
  end

  % properties for conversion type 'Formula'
  properties(PropertyType = 'double scalar')
    % minimum value
	ConversionFormula_RangeMin = 0;
  end
  properties(PropertyType = 'double scalar')
    % maximum value
	ConversionFormula_RangeMax = 0;
  end
  properties(PropertyType = 'char')
    % Description of the Formula as text
	ConversionFormula_Formula = '';
  end

  % properties for conversion type 'Lienar'
  properties(PropertyType = 'double scalar')
    % Raw value of starting point
	ConversionLinear_Raw1 = 0;
  end
  properties(PropertyType = 'double scalar')
    % Physical value of starting point
	ConversionLinear_Phy1 = 0;
  end
  properties(PropertyType = 'double scalar')
    % Raw value of end point
	ConversionLinear_Raw2 = 0;
  end
  properties(PropertyType = 'double scalar')
    % Physical value of end point
	ConversionLinear_Phy2 = 0;
  end
end % classdef
