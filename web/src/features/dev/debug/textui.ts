import { TextUiProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugTextUI = () => {
  debugData<TextUiProps>([
    {
      action: 'textUi',
      data: {
        text: '[E] - Open the saddlebags  \n [G] - Do something else',
        position: 'right-center',
        icon: 'lock',
      },
    },
  ]);
};
