function validateForm()
{
	var errString='';
	if(jQuery("#email").val()=='')
	{
		errString="Email is a required field\n";
	}
	if(jQuery("#password").val()=='')
	{
		errString+="Password is a requried field\n";
	}
	if(jQuery("#confirm_pass").val()=='')
	{
		errString+="Password confirmation is a required field\n";
	}
	if(jQuery("#password").val() != jQuery("#confirm_pass").val())
	{
		errString+="Password and password confirmation must match\n";
	}
	if(errString!='')
	{
		alert(errString);
		return false;
	}
	return true;
}
